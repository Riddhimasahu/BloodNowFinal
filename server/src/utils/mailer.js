import nodemailer from 'nodemailer';
import '../loadEnv.js';

let transporter;

export async function sendSosEmail(toEmail, subject, htmlBody) {
  if (!toEmail) return;

  if (!transporter) {
    if (process.env.SMTP_USER && process.env.SMTP_PASS) {
      transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST || 'smtp.gmail.com',
        port: Number(process.env.SMTP_PORT) || 587,
        secure: process.env.SMTP_SECURE === 'true', // true for 465, false for other ports
        auth: {
          user: process.env.SMTP_USER,
          pass: process.env.SMTP_PASS,
        },
      });
    } else {
      console.warn('\\n⚠️ No SMTP credentials in .env. Generating a free Ethereal Test Email Server...\\n');
      const testAccount = await nodemailer.createTestAccount();
      transporter = nodemailer.createTransport({
        host: testAccount.smtp.host,
        port: testAccount.smtp.port,
        secure: testAccount.smtp.secure,
        auth: {
          user: testAccount.user,
          pass: testAccount.pass,
        },
      });
    }
  }

  try {
    const info = await transporter.sendMail({
      from: process.env.SMTP_FROM || '"BloodNow SOS Alert" <noreply@bloodnow.localhost>',
      to: toEmail,
      subject: subject,
      html: htmlBody,
    });
    console.log('SOS Email dispatched: %s to %s', info.messageId, toEmail);

    const previewUrl = nodemailer.getTestMessageUrl(info);
    if (previewUrl) {
      console.log('----------------------------------------------------');
      console.log('📧 TEST EMAIL SENT SUCESSFULLY!');
      console.log('👉 CLICK HERE TO VIEW IT: %s', previewUrl);
      console.log('----------------------------------------------------');
    }
  } catch (err) {
    console.error('Failed to send SOS Email:', err);
  }
}

export async function sendImpactEmail(email, bloodGroup, dateStr) {
  if (!email) return;

  if (!transporter) {
    if (process.env.SMTP_USER && process.env.SMTP_PASS) {
      transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST || 'smtp.gmail.com',
        port: Number(process.env.SMTP_PORT) || 587,
        secure: process.env.SMTP_SECURE === 'true',
        auth: {
          user: process.env.SMTP_USER,
          pass: process.env.SMTP_PASS,
        },
      });
    } else {
      console.warn('\\n⚠️ No SMTP credentials in .env. Generating a free Ethereal Test Email Server...\\n');
      const testAccount = await nodemailer.createTestAccount();
      transporter = nodemailer.createTransport({
        host: testAccount.smtp.host,
        port: testAccount.smtp.port,
        secure: testAccount.smtp.secure,
        auth: {
          user: testAccount.user,
          pass: testAccount.pass,
        },
      });
    }
  }

  const subject = "Your Blood Saved a Life Today! ❤️";
  const html = `
    <div style="font-family: Arial, sans-serif; background-color: #fce4e4; padding: 20px; border-radius: 10px; max-width: 600px; margin: 0 auto; color: #333;">
      <h2 style="color: #c62828; text-align: center;">You Are a Hero! 🩸</h2>
      <p style="font-size: 16px;">Hello,</p>
      <p style="font-size: 16px; line-height: 1.5;">
        We are thrilled to let you know that your <strong>${bloodGroup}</strong> blood donation on <strong>${dateStr}</strong> has just been used to help a patient in need.
      </p>
      <p style="font-size: 16px; line-height: 1.5;">
        Thank you for your selfless act. Because of your kindness, someone has a second chance at life today. 
      </p>
      <div style="text-align: center; margin: 30px 0;">
        <span style="font-size: 40px;">🦸‍♂️🦸‍♀️</span>
      </div>
      <p style="font-size: 16px; text-align: center;">
        <strong>Keep up the amazing work!</strong>
      </p>
      <p style="font-size: 14px; text-align: center; color: #777; margin-top: 30px;">
        - The BloodNow Team
      </p>
    </div>
  `;

  try {
    const info = await transporter.sendMail({
      from: process.env.SMTP_FROM || '"BloodNow Impact" <noreply@bloodnow.localhost>',
      to: email,
      subject: subject,
      html: html,
    });
    console.log('Impact Email dispatched: %s to %s', info.messageId, email);

    // This is for test mode
    const previewUrl = nodemailer.getTestMessageUrl(info);
    if (previewUrl) {
      console.log('----------------------------------------------------');
      console.log('📧 TEST EMAIL SENT SUCESSFULLY!');
      console.log('👉 CLICK HERE TO VIEW IT: %s', previewUrl);
      console.log('----------------------------------------------------');
    }
  } catch (err) {
    console.error('Failed to send Impact Email:', err);
  }
}

export async function sendGenericEmail(toEmail, subject, htmlBody) {
  if (!toEmail) return;

  if (!transporter) {
    if (process.env.SMTP_USER && process.env.SMTP_PASS) {
      transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST || 'smtp.gmail.com',
        port: Number(process.env.SMTP_PORT) || 587,
        secure: process.env.SMTP_SECURE === 'true',
        auth: {
          user: process.env.SMTP_USER,
          pass: process.env.SMTP_PASS,
        },
      });
    } else {
      console.warn('\n⚠️ No SMTP credentials in .env. Generating a free Ethereal Test Email Server...\n');
      const testAccount = await nodemailer.createTestAccount();
      transporter = nodemailer.createTransport({
        host: testAccount.smtp.host,
        port: testAccount.smtp.port,
        secure: testAccount.smtp.secure,
        auth: {
          user: testAccount.user,
          pass: testAccount.pass,
        },
      });
    }
  }

  try {
    const info = await transporter.sendMail({
      from: process.env.SMTP_FROM || '"BloodNow Notification" <noreply@bloodnow.localhost>',
      to: toEmail,
      subject: subject,
      html: htmlBody,
    });
    console.log('Email dispatched: %s to %s', info.messageId, toEmail);

    const previewUrl = nodemailer.getTestMessageUrl(info);
    if (previewUrl) {
      console.log('----------------------------------------------------');
      console.log('📧 TEST EMAIL SENT SUCESSFULLY!');
      console.log('👉 CLICK HERE TO VIEW IT: %s', previewUrl);
      console.log('----------------------------------------------------');
    }
  } catch (err) {
    console.error('Failed to send email:', err);
  }
}
