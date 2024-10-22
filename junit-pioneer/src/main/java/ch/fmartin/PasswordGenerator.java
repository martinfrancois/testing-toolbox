package ch.fmartin;

import java.security.SecureRandom;

public class PasswordGenerator {

    private static final String LOWER = "abcdefghijklmnopqrstuvwxyz";
    private static final String UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    private static final String DIGITS = "0123456789";
    private static final String SYMBOLS = "!@#$%^&*";

    public String generatePassword(int length, boolean alpha, boolean numeric, boolean uppercase, boolean symbols) {
        if (length <= 0 || (!alpha && !numeric && !uppercase && !symbols)) {
            throw new IllegalArgumentException("Invalid parameters for password generation");
        }

        StringBuilder characterPool = new StringBuilder();
        if (alpha) characterPool.append(LOWER);
        if (uppercase) characterPool.append(UPPER);
        if (numeric) characterPool.append(DIGITS);
        if (symbols) characterPool.append(SYMBOLS);

        SecureRandom random = new SecureRandom();
        StringBuilder password = new StringBuilder(length);
        for (int i = 0; i < length; i++) {
            password.append(characterPool.charAt(random.nextInt(characterPool.length())));
        }

        return password.toString();
    }
}
