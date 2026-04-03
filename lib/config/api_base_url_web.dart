String resolveApiBaseUrl() {
  const fromEnv = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  if (fromEnv.isNotEmpty) return fromEnv;
  return 'http://127.0.0.1:3000';
}
