package ch.fmartin;

import com.fasterxml.jackson.databind.ObjectMapper;

import java.math.BigDecimal;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.Map;
import java.util.Optional;

public class CurrencyConversionClient {

    private static final String API_URL = "https://open.er-api.com/v6/latest/";
    private final HttpClient httpClient = HttpClient.newHttpClient();
    private final ObjectMapper objectMapper = new ObjectMapper();

    public Optional<BigDecimal> getConversionRate(String fromCurrency, String toCurrency) throws Exception {
        String url = API_URL + fromCurrency;
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .GET()
                .build();

        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

        if (response.statusCode() == 200) {
            Map<String, Object> responseMap = objectMapper.readValue(response.body(), Map.class);
            Map<String, Double> rates = (Map<String, Double>) responseMap.get("rates");

            if (rates != null && rates.get(toCurrency) != null) {
                return Optional.of(BigDecimal.valueOf(rates.get(toCurrency)));
            }
        }

        return Optional.empty();
    }
}
