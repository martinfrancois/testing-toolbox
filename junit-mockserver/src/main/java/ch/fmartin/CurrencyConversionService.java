package ch.fmartin;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Optional;

public class CurrencyConversionService {

    private CurrencyConversionClient currencyConversionClient;

    public CurrencyConversionService() {
        this.currencyConversionClient = new CurrencyConversionClient();
    }

    public CurrencyConversionService(CurrencyConversionClient currencyConversionClient) {
        this.currencyConversionClient = currencyConversionClient;
    }

    public Optional<BigDecimal> convertCurrency(BigDecimal amount, String fromCurrency, String toCurrency) throws Exception {
        return currencyConversionClient.getConversionRate(fromCurrency, toCurrency)
                .map(multiplicand -> amount
                        .multiply(multiplicand)
                        .setScale(2, RoundingMode.HALF_EVEN)
                );
    }
}
