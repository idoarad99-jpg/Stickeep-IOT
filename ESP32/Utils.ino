String generateSeatSerial(String seatId) {
  int firstUnderscore = seatId.indexOf('_');
  int secondUnderscore = seatId.indexOf('_', firstUnderscore + 1);

  if (firstUnderscore == -1 || secondUnderscore == -1) {
    return seatId;
  }

  String part1 = seatId.substring(0, firstUnderscore);                    // SEAT
  String part2 = seatId.substring(firstUnderscore + 1, secondUnderscore); // T2
  String part3 = seatId.substring(secondUnderscore + 1);                  // 1

  String serial = "";

  serial += part1.charAt(0); // S
  serial += part2.charAt(0); // T

  for (int i = 0; i < part2.length(); i++) {
    if (isDigit(part2.charAt(i))) {
      serial += part2.charAt(i);
    }
  }

  serial += part3;

  return serial;
}