package ch.fmartin;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.math.BigDecimal;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.Optional;

public class CurrencyConversionClient {

    private final String apiUrl;
    private final HttpClient httpClient = HttpClient.newHttpClient();
    private final ObjectMapper objectMapper = new ObjectMapper();

    public CurrencyConversionClient() {
        this.apiUrl = "https://open.er-api.com/v6/latest/";
    }

    public CurrencyConversionClient(String apiUrl) {
        this.apiUrl = apiUrl;
    }

    public Optional<BigDecimal> getConversionRate(String fromCurrency, String toCurrency) throws Exception {
        String url = apiUrl + fromCurrency;
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .GET()
                .build();

        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

        if (response.statusCode() == 200) {
            JsonNode rate = objectMapper.readTree(response.body()).path("rates").path(toCurrency);
            if (rate.isNumber()) {
                return Optional.of(rate.decimalValue());
            }
        }

        return Optional.empty();
    }
}
