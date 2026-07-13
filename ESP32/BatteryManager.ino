// ====================================================
// Battery Manager
// ====================================================

int getBatteryPercentage()
{
  // No real battery sensor wired up yet — fixed placeholder value.
  return 100;
}

void updateBatteryStatus()
{
  int battery = getBatteryPercentage();

  batteryText = String(battery) + "%";

  if (batteryText != previousBatteryText)
  {
    previousBatteryText = batteryText;

    drawTopStatusBar();
  }
}