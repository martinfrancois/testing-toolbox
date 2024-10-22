package ch.fmartin;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockserver.client.MockServerClient;
import org.mockserver.configuration.ConfigurationProperties;
import org.mockserver.file.FileReader;
import org.mockserver.junit.jupiter.MockServerExtension;

import java.io.IOException;
import java.util.logging.LogManager;

import java.io.ByteArrayInputStream;
import java.math.BigDecimal;
import java.util.Optional;

import static java.nio.charset.StandardCharsets.UTF_8;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockserver.configuration.ConfigurationProperties.javaLoggerLogLevel;
import static org.mockserver.mock.OpenAPIExpectation.openAPIExpectation;

@ExtendWith(MockServerExtension.class)
class CurrencyConversionServiceTest {

    @Test
    void convertCurrency(MockServerClient mockserver) throws Exception {
        // given
        mockserver.upsert(openAPIExpectation(FileReader.readFileFromClassPathOrPath("openapi.json")));

        CurrencyConversionClient client = new CurrencyConversionClient("http://localhost:" + mockserver.getPort() + "/v6/latest/");
        CurrencyConversionService service = new CurrencyConversionService(client);

        BigDecimal usdAmount = new BigDecimal("100");

        // when
        Optional<BigDecimal> result = service.convertCurrency(usdAmount, "USD", "EUR");

        // then
        assertEquals(Optional.of(new BigDecimal("91.90")), result);
    }

    // Show MockServer logs
    @BeforeEach
    void setUp() throws IOException {
        ConfigurationProperties.logLevel("INFO");
        String loggingConfiguration = "" +
                "handlers=org.mockserver.logging.StandardOutConsoleHandler\n" +
                "org.mockserver.logging.StandardOutConsoleHandler.level=ALL\n" +
                "org.mockserver.logging.StandardOutConsoleHandler.formatter=java.util.logging.SimpleFormatter\n" +
                "java.util.logging.SimpleFormatter.format=%1$tF %1$tT  %3$s  %4$s  %5$s %6$s%n\n" +
                ".level=" + javaLoggerLogLevel() + "\n" +
                "io.netty.handler.ssl.SslHandler.level=WARNING";
        LogManager.getLogManager().readConfiguration(new ByteArrayInputStream(loggingConfiguration.getBytes(UTF_8)));
    }

}
