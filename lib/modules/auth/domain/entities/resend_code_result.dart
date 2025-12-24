class ResendCodeResult {
  final int otpTtlSeconds;
  final bool mailQueued;
  final int cooldownSeconds;

  const ResendCodeResult({
    required this.otpTtlSeconds,
    required this.mailQueued,
    required this.cooldownSeconds,
  });
}
