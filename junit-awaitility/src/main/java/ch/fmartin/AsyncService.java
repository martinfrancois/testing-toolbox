package ch.fmartin;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class AsyncService {
    private final List<String> data = new ArrayList<>();
    private final ExecutorService executor = Executors.newSingleThreadExecutor();

    public void addData(String item) {
        executor.submit(() -> {
            try {
                // Simulate delay
                Thread.sleep(2000);
                data.add(item);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        });
    }

    public List<String> getData() {
        return Collections.unmodifiableList(data);
    }
}
