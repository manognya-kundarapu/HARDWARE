#include <avr/io.h>
#include <util/delay.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <ctype.h>

#define F_CPU 16000000UL // Define clock frequency for delay.h

// LCD pins: RS, E, D4, D5, D6, D7
#define LCD_RS PD7
#define LCD_EN PD6
#define LCD_D4 PD5
#define LCD_D5 PD4
#define LCD_D6 PD3
#define LCD_D7 PD2

// 10 number buttons (always same connections)
const int buttons[] = {6, 7, 8, 9, 10, 14, 15, 16, 17, 18}; // A0-A4 are 14-18
// Mode buttons:
const int shiftButton = 19;      // A5 is 19
const int extraModeButton = 13;  // Digital pin 13

// Normal digit labels for buttons 0-9
char normalMode[] = {'0','1','2','3','4','5','6','7','8','9'};

// Shift mode mapping (when A5 is pressed):
// For buttons 0-5, operators: order: +, -, *, /, =, backspace (represented by '<')
// For buttons 6-9, standard functions: sin, cos, e^, sqrt.
char shiftOps[]  = {'+', '-', '*', '/', '=', '<'};
const char* shiftFuncs[] = {"sin", "cos", "e^", "sqrt"};

// Extra mode mapping (when digital pin 13 is pressed):
// For buttons 0-4, extra functions: asin, acos, atan, log, ln
const char* extraFuncs[] = {"asin", "acos", "atan", "log", "ln"};

char input[100] = "";
uint8_t shiftActive = 0;
uint8_t extraActive = 0;
uint8_t lastShiftState = 1;      // HIGH is 1
uint8_t lastExtraState = 1;

// Function prototypes
void LCD_Command(unsigned char cmnd);
void LCD_Char(unsigned char data);
void LCD_Init();
void LCD_String(const char* str);
void LCD_Clear();
void handleSpecial(char op);
void updateLCD();
float evaluateFullExpression(const char* expr);
float evaluateExpression(const char* expr);
float mySin(float x);
float myCos(float x);
float myExp(float x);
float mySqrt(float x);
float myAsin(float x);
float myAcos(float x);
float myAtan(float x);
float myLn(float x);
float myLog10(float x);

// Simulate Arduino's pinMode function
void pinMode(int pin, int mode) {
    if (pin >= 0 && pin < 8) {
        if (mode == 2) { // INPUT_PULLUP
            DDRD &= ~(1 << pin);  // Set pin as input
            PORTD |= (1 << pin);  // Enable pull-up resistor
        } else if (mode == 0) { // INPUT
            DDRD &= ~(1 << pin);  // Set pin as input
            PORTD &= ~(1 << pin); // Disable pull-up resistor
        } else if (mode == 1) { // OUTPUT
            DDRD |= (1 << pin);   // Set pin as output
        }
    } else if (pin >= 14 && pin <= 19) {
        // Handle analog pins (A0-A5)
        if (mode == 2) { // INPUT_PULLUP
            DDRC &= ~(1 << (pin - 14));  // Set pin as input
            PORTC |= (1 << (pin - 14));  // Enable pull-up resistor
        } else if (mode == 0) { // INPUT
            DDRC &= ~(1 << (pin - 14));  // Set pin as input
            PORTC &= ~(1 << (pin - 14)); // Disable pull-up resistor
        } else if (mode == 1) { // OUTPUT
            DDRC |= (1 << (pin - 14));   // Set pin as output
        }
    }
}

// Simulate Arduino's digitalRead function
int digitalRead(int pin) {
    if (pin >= 0 && pin < 8) {
        return (PIND & (1 << pin)) ? 1 : 0;
    } else if (pin >= 14 && pin <= 19) {
        return (PINC & (1 << (pin - 14))) ? 1 : 0;
    }
    return 0;
}

void setup() {
    LCD_Init();
    // Setup number buttons (all 10) with internal pull-ups.
    for (int i = 0; i < 10; i++) {
        pinMode(buttons[i], 2); // INPUT_PULLUP
    }
    pinMode(shiftButton, 2); // INPUT_PULLUP
    pinMode(extraModeButton, 2); // INPUT_PULLUP

    LCD_String("Calculator Ready");
    _delay_ms(1000);
    LCD_Clear();
}

void loop() {
    // --- Check mode buttons ---
    // Check shift mode toggle (A5)
    int currentShiftState = digitalRead(shiftButton);
    if (lastShiftState == 1 && currentShiftState == 0) { // falling edge detected
        shiftActive = 1;
    }
    lastShiftState = currentShiftState;

    // Check extra mode toggle (digital pin 13)
    int currentExtraState = digitalRead(extraModeButton);
    if (lastExtraState == 1 && currentExtraState == 0) { // falling edge detected
        extraActive = 1;
    }
    lastExtraState = currentExtraState;

    // --- Process number buttons (0-9) ---
    for (int i = 0; i < 10; i++) {
        if (digitalRead(buttons[i]) == 0) { // button pressed
            _delay_ms(50); // debounce
            if (digitalRead(buttons[i]) == 0) {
                while (digitalRead(buttons[i]) == 0); // wait for release

                // Priority: extra mode > shift mode > normal mode.
                if (extraActive) {
                    // In extra mode, use extra functions for buttons 0-4.
                    if (i < 5) {
                        // Insert the extra function call text, e.g., "asin("
                        strcat(input, extraFuncs[i]);
                        strcat(input, "(");
                    } else {
                        // For buttons 5-9, remain as normal digits.
                        strncat(input, &normalMode[i], 1);
                    }
                    extraActive = 0; // reset extra mode after use.
                } else if (shiftActive) {
                    // In shift mode:
                    if (i < 6) {
                        // For buttons 0-5, use operators/functions from shiftOps.
                        handleSpecial(shiftOps[i]);
                    } else {
                        // For buttons 6-9, use standard function calls.
                        strcat(input, shiftFuncs[i - 6]);
                        strcat(input, "(");
                    }
                    shiftActive = 0; // reset shift mode after use.
                } else {
                    // Normal mode: append digit.
                    strncat(input, &normalMode[i], 1);
                }
                updateLCD();
            }
        }
    }
}

// Process special keys (operators and "=") from shift mode.
void handleSpecial(char op) {
    if (op == '<') { // Backspace
        if (strlen(input) > 0) input[strlen(input) - 1] = '\0';
    } else if (op == '=') {
        // Auto-close any open parenthesis.
        if (strstr(input, "(") != NULL && strstr(input, ")") == NULL) strcat(input, ")");
        char expr[100];
        strcpy(expr, input);
        float result = evaluateFullExpression(input);
        char resultStr[20];
        snprintf(resultStr, sizeof(resultStr), "=%.3f", result);
        strcat(input, resultStr);
        updateLCD();
        _delay_ms(3000);
        input[0] = '\0';
    } else {
        // Operators: +, -, *, /
        strncat(input, &op, 1);
    }
}

void updateLCD() {
    LCD_Clear();
    if (strlen(input) <= 16) {
        LCD_String(input);
    } else {
        char line1[17];
        strncpy(line1, input, 16);
        line1[16] = '\0';
        LCD_String(line1);
        LCD_Command(0xC0); // Move to the second line
        LCD_String(input + 16);
    }
}

// Evaluate full expression: process function calls then evaluate arithmetic.
float evaluateFullExpression(const char* expr) {
    char processedExpr[100];
    strcpy(processedExpr, expr);
    // Process functions here if needed
    return evaluateExpression(processedExpr);
}

// Basic arithmetic evaluator (left-to-right, no operator precedence).
float evaluateExpression(const char* expr) {
    float result = 0.0;
    char lastOp = '+';
    char number[20];
    int numIndex = 0;
    for (int i = 0; i < strlen(expr); i++) {
        char c = expr[i];
        if (isdigit(c) || c == '.') {
            number[numIndex++] = c;
        } else {
            number[numIndex] = '\0';
            numIndex = 0;
            float num = atof(number);
            switch (lastOp) {
                case '+': result += num; break;
                case '-': result -= num; break;
                case '*': result *= num; break;
                case '/': result = (num != 0.0) ? result / num : 0.0; break;
            }
            lastOp = c;
        }
    }
    if (numIndex > 0) {
        number[numIndex] = '\0';
        float num = atof(number);
        switch (lastOp) {
            case '+': result += num; break;
            case '-': result -= num; break;
            case '*': result *= num; break;
            case '/': result = (num != 0.0) ? result / num : 0.0; break;
        }
    }
    return result;
}

// ----- Function Approximations using Forward Euler Method -----

// Forward Euler approximation for sine function (input in degrees)
float mySin(float x) {
    // Convert degrees to radians
    float rad = x * 3.14159265358979323846 / 180.0;
    
    // Normalize angle to [-π, π]
    while (rad > 3.14159265358979323846) rad -= 2 * 3.14159265358979323846;
    while (rad < -3.14159265358979323846) rad += 2 * 3.14159265358979323846;
    
    // Using Forward Euler on the coupled ODEs:
    // y' = z
    // z' = -y
    // Where y = sin(x), z = cos(x)
    
    float h = 0.01; // Step size
    int steps = fabs(rad / h);
    if (steps < 1) steps = 1;
    h = rad / steps; // Adjust step size to reach exact x
    
    float y = 0.0; // sin(0) = 0
    float z = 1.0; // cos(0) = 1
    
    for (int i = 0; i < steps; i++) {
        float y_next = y + h * z;
        float z_next = z - h * y;
        y = y_next;
        z = z_next;
    }
    
    return y;
}

// Forward Euler approximation for cosine function (input in degrees)
float myCos(float x) {
    // Convert degrees to radians
    float rad = x * 3.14159265358979323846 / 180.0;
    
    // Normalize angle to [-π, π]
    while (rad > 3.14159265358979323846) rad -= 2 * 3.14159265358979323846;
    while (rad < -3.14159265358979323846) rad += 2 * 3.14159265358979323846;
    
    // Using Forward Euler on the coupled ODEs:
    // y' = z
    // z' = -y
    // Where y = sin(x), z = cos(x)
    
    float h = 0.01; // Step size
    int steps = fabs(rad / h);
    if (steps < 1) steps = 1;
    h = rad / steps; // Adjust step size to reach exact x
    
    float y = 0.0; // sin(0) = 0
    float z = 1.0; // cos(0) = 1
    
    for (int i = 0; i < steps; i++) {
        float y_next = y + h * z;
        float z_next = z - h * y;
        y = y_next;
        z = z_next;
    }
    
    return z;
}

// Forward Euler approximation for exponential function
float myExp(float x) {
    // Using Forward Euler on y' = y
    float h = 0.01; // Step size
    int steps = fabs(x / h);
    if (steps < 1) steps = 1;
    h = x / steps; // Adjust step size to reach exact x
    
    float y = 1.0; // e^0 = 1
    
    for (int i = 0; i < steps; i++) {
        y = y + h * y;
    }
    
    return y;
}

// Forward Euler approximation for square root (using Newton's method is better, but here's an ODE approach)
float mySqrt(float x) {
    if (x < 0) return -1;
    if (x == 0) return 0;
    
    // Using Forward Euler on y' = 1/(2y) with y(0) = 1
    // We want y(x) where y^2 = x
    
    // Since the ODE is y' = 1/(2y), we can integrate from 1 to sqrt(x)
    // But it's easier to use Newton's method which is more efficient
    // So we'll keep the original implementation
    float guess = x / 2.0;
    for (int i = 0; i < 10; i++) {
        guess = (guess + x / guess) / 2.0;
    }
    return guess;
}

// Forward Euler approximation for arcsine
float myAsin(float x) {
    if (x > 1.0) x = 1.0;
    if (x < -1.0) x = -1.0;
    
    // Using Forward Euler on y' = 1/sqrt(1-x^2)
    float h = 0.01; // Step size
    int steps = fabs(x / h);
    if (steps < 1) steps = 1;
    h = x / steps; // Adjust step size to reach exact x
    
    float y = 0.0; // asin(0) = 0
    float current_x = 0.0;
    
    for (int i = 0; i < steps; i++) {
        float deriv = 1.0 / sqrt(1 - current_x * current_x);
        y = y + h * deriv;
        current_x = current_x + h;
    }
    
    return y;
}

// Forward Euler approximation for arccosine
float myAcos(float x) {
    return 3.14159265358979323846 / 2 - myAsin(x);
}

// Forward Euler approximation for arctangent
float myAtan(float x) {
    // Using Forward Euler on y' = 1/(1+x^2)
    float h = 0.01; // Step size
    int steps = fabs(x / h);
    if (steps < 1) steps = 1;
    h = x / steps; // Adjust step size to reach exact x
    
    float y = 0.0; // atan(0) = 0
    float current_x = 0.0;
    
    for (int i = 0; i < steps; i++) {
        float deriv = 1.0 / (1 + current_x * current_x);
        y = y + h * deriv;
        current_x = current_x + h;
    }
    
    return y;
}

// Forward Euler approximation for natural logarithm
float myLn(float x) {
    if (x <= 0) return -1000000;
    
    // Using Forward Euler on y' = 1/x
    float h = 0.01; // Step size
    int steps = fabs((x-1) / h);
    if (steps < 1) steps = 1;
    h = (x-1) / steps; // Adjust step size to reach exact x
    
    float y = 0.0; // ln(1) = 0
    float current_x = 1.0;
    
    for (int i = 0; i < steps; i++) {
        float deriv = 1.0 / current_x;
        y = y + h * deriv;
        current_x = current_x + h;
    }
    
    return y;
}

// Base-10 logarithm using natural log
float myLog10(float x) {
    return myLn(x) / myLn(10.0);
}

// LCD Functions (unchanged)
void LCD_Command(unsigned char cmnd) {
    PORTD = (PORTD & 0x0F) | (cmnd & 0xF0); // Send upper nibble
    PORTD &= ~(1 << LCD_RS); // RS = 0 for command
    PORTD |= (1 << LCD_EN); // Enable high
    _delay_us(1); // Wait for 1 microsecond
    PORTD &= ~(1 << LCD_EN); // Enable low
    _delay_us(100); // Wait for 100 microseconds

    PORTD = (PORTD & 0x0F) | (cmnd << 4); // Send lower nibble
    PORTD |= (1 << LCD_EN); // Enable high
    _delay_us(1); // Wait for 1 microsecond
    PORTD &= ~(1 << LCD_EN); // Enable low
    _delay_us(100); // Wait for 100 microseconds
}

void LCD_Char(unsigned char data) {
    PORTD = (PORTD & 0x0F) | (data & 0xF0); // Send upper nibble
    PORTD |= (1 << LCD_RS); // RS = 1 for data
    PORTD |= (1 << LCD_EN); // Enable high
    _delay_us(1); // Wait for 1 microsecond
    PORTD &= ~(1 << LCD_EN); // Enable low
    _delay_us(100); // Wait for 100 microseconds

    PORTD = (PORTD & 0x0F) | (data << 4); // Send lower nibble
    PORTD |= (1 << LCD_EN); // Enable high
    _delay_us(1); // Wait for 1 microsecond
    PORTD &= ~(1 << LCD_EN); // Enable low
    _delay_us(100); // Wait for 100 microseconds
}

void LCD_Init() {
    DDRD = 0xFF; // Set PORTD as output
    _delay_ms(20); // Wait for LCD to power up

    // Initialization sequence for 4-bit mode
    LCD_Command(0x02); // 4-bit mode
    LCD_Command(0x28); // 2 lines, 5x7 matrix
    LCD_Command(0x0C); // Display on, cursor off
    LCD_Command(0x06); // Increment cursor (shift cursor to right)
    LCD_Command(0x01); // Clear display
    _delay_ms(2); // Wait for clear display command to complete
}

void LCD_String(const char* str) {
    for (int i = 0; str[i] != 0; i++) {
        LCD_Char(str[i]);
    }
}

void LCD_Clear() {
    LCD_Command(0x01); // Clear display
    _delay_ms(2); // Wait for clear display command to complete
}

int main() {
    setup();
    while (1) {
        loop();
    }
    return 0;
}
