package ch.fmartin;

import org.awaitility.Awaitility;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.MethodSource;
import org.junit.jupiter.params.provider.ValueSource;

import java.util.List;
import java.util.concurrent.TimeUnit;
import java.util.stream.Stream;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.params.provider.Arguments.arguments;

class AsyncServiceTest {

    @Test
    void addData() {
        // given
        AsyncService service = new AsyncService();
        List<String> data = service.getData();
        String text = "Hello Awaitility!";

        // when
        service.addData(text);

        // then
        //assertTrue((data).contains(text));

        Awaitility.await()
                .atMost(5, TimeUnit.SECONDS)  // Maximum time to wait
                .untilAsserted(() -> {
                    // verify data has been added to the list
                    assertTrue((data).contains(text));
                });
    }
}