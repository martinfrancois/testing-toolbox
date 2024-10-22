package ch.fmartin;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CurrencyConversionServiceTest {

    @InjectMocks
    private CurrencyConversionService service;

    @Mock
    private CurrencyConversionClient mockClient;

    @Test
    void convertCurrency() throws Exception {
        // given
        when(mockClient.getConversionRate("USD", "EUR")).thenReturn(Optional.of(new BigDecimal("0.919")));
        BigDecimal usdAmount = new BigDecimal("100");

        // when
        Optional<BigDecimal> result = service.convertCurrency(usdAmount, "USD", "EUR");

        // then
        assertEquals(Optional.of(new BigDecimal("91.90")), result);
    }

}