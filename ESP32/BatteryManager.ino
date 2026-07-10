// ====================================================
// Battery Manager
// ====================================================

int getBatteryPercentage()
{
  // כרגע אין סוללה, לכן מחזירים ערך לבדיקה
  return 100;

  // בהמשך:
  // return calculateBatteryPercent();
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