package ch.fmartin;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.MethodSource;
import org.junit.jupiter.params.provider.ValueSource;

import java.util.stream.Stream;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.params.provider.Arguments.arguments;

class CalculatorTest {

    @ParameterizedTest
    @ValueSource(ints = {-3, -1, 1, 3, 15, Integer.MAX_VALUE})
    void isOdd_ShouldReturnTrueForOddNumbers(int number) {
        assertTrue(Calculator.isOdd(number));
    }

    @ParameterizedTest(name = "{index} => {0} + {1} = {2}")
    @CsvSource({
            "0, 0, 0",
            "0, 1, 1",
            "1, 0, 1",
            "1, 1, 2",
    })
    void add_WithCsvSource(int a, int b, int expected) {
        assertEquals(expected, Calculator.add(a, b));
    }

    @ParameterizedTest(name = "[{index}] {0} + {1} = {2}")
    @MethodSource("addProvider")
    void add_WithMethodSource(int a, int b, int expected) {
        assertEquals(expected, Calculator.add(a, b));
    }

    static Stream<Arguments> addProvider() {
        return Stream.of(
                //        a, b, expected
                arguments(0, 0, 0),
                arguments(0, 1, 1),
                arguments(1, 0, 1),
                arguments(1, 1, 2)
        );
    }

}