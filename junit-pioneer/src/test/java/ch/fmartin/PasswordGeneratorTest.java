package ch.fmartin;

import org.junitpioneer.jupiter.cartesian.CartesianTest;
import org.junitpioneer.jupiter.cartesian.CartesianTest.Values;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class PasswordGeneratorTest {

    PasswordGenerator passwordGenerator = new PasswordGenerator();

    @CartesianTest(name = "[{index}] length = {0} | alpha = {1} | numeric = {2} | uppercase = {3} | symbols = {4}")
    void testGeneratePassword(
            @Values(ints = {8, 12}) int length,
            @Values(booleans = {true, false}) boolean alpha,
            @Values(booleans = {true, false}) boolean numeric,
            @Values(booleans = {true, false}) boolean uppercase,
            @Values(booleans = {true, false}) boolean symbols
    ) {
        // when
        String password = passwordGenerator.generatePassword(length, alpha, numeric, uppercase, symbols);

        // then
        assertEquals(length, password.length());

        if (alpha) {
            assertTrue(password.chars().anyMatch(Character::isLowerCase),
                    "Password " + password + " must contain alphabetic characters");
        }
        if (numeric) {
            assertTrue(password.chars().anyMatch(Character::isDigit),
                    "Password " + password + " must contain numeric characters");
        }
        if (uppercase) {
            assertTrue(password.chars().anyMatch(Character::isUpperCase),
                    "Password " + password + " must contain uppercase characters");
        }
        if (symbols) {
            assertThat(password)
                    .containsAnyOf("!", "@", "#", "$", "%", "^", "&", "*");
        }
    }
}