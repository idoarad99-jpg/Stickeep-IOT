// Vendored copy of TFT_eSPI's own Setup25_TTGO_T_Display.h, included as
// a sketch-local header (before <TFT_eSPI.h>) instead of editing the
// shared library's User_Setup_Select.h — editing the library directly
// would silently affect every other TFT_eSPI sketch on the same
// machine. USER_SETUP_LOADED tells TFT_eSPI to skip its own
// User_Setup_Select.h entirely and use exactly these defines.
//
// These pins are fixed by the TTGO T-Display board itself (soldered to
// its built-in screen) — nothing else can use GPIO 4, 5, 16, 18, 19, 23.

#define USER_SETUP_LOADED 1

#define ST7789_DRIVER
#define TFT_SDA_READ

#define TFT_WIDTH  135
#define TFT_HEIGHT 240

#define CGRAM_OFFSET

#define TFT_MOSI 19
#define TFT_SCLK 18
#define TFT_CS    5
#define TFT_DC   16
#define TFT_RST  23

#define TFT_BL    4
#define TFT_BACKLIGHT_ON HIGH

#define LOAD_GLCD
#define LOAD_FONT2
#define LOAD_FONT4
#define LOAD_FONT6
#define LOAD_FONT7
#define LOAD_FONT8
#define LOAD_GFXFF

#define SMOOTH_FONT

#define SPI_FREQUENCY  40000000
#define SPI_READ_FREQUENCY  6000000
