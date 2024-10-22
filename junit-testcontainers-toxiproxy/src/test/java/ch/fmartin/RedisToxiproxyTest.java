package ch.fmartin;

import eu.rekawek.toxiproxy.Proxy;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.AfterEach;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.Network;
import org.testcontainers.containers.ToxiproxyContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import redis.clients.jedis.Jedis;
import redis.clients.jedis.exceptions.JedisConnectionException;
import eu.rekawek.toxiproxy.ToxiproxyClient;
import eu.rekawek.toxiproxy.model.ToxicDirection;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.catchThrowable;
import static org.junit.jupiter.api.Assertions.*;

@Testcontainers
class RedisToxiproxyTest {
    private static final String KEY = "somekey";
    private static final String VALUE = "somevalue";

    private static Network network = Network.newNetwork();

    private Jedis jedis;
    private Proxy proxy;

    @Container
    public GenericContainer<?> redis = new GenericContainer<>("redis:6-alpine")
            .withExposedPorts(6379)
            .withNetwork(network)
            .withNetworkAliases("redis");

    @Container
    public ToxiproxyContainer toxiproxy = new ToxiproxyContainer("ghcr.io/shopify/toxiproxy:2.11.0")
            .withNetwork(network);

    @BeforeEach
    public void setUp() throws Exception {
        ToxiproxyClient toxiproxyClient = new ToxiproxyClient(toxiproxy.getHost(), toxiproxy.getControlPort());
        proxy = toxiproxyClient.createProxy("redis", "0.0.0.0:8666", "redis:6379");

        // Connect Jedis through Toxiproxy
        String ipAddressViaToxiproxy = toxiproxy.getHost();
        int portViaToxiproxy = toxiproxy.getMappedPort(8666);
        jedis = new Jedis(ipAddressViaToxiproxy, portViaToxiproxy);

        // Set initial data
        jedis.set(KEY, VALUE);
    }

    @AfterEach
    public void tearDown() {
        jedis.close();
    }

    @Test
    public void withLatencyAndJitter() throws Exception {
        // given: introduce latency and jitter
        proxy.toxics()
                .latency("latency", ToxicDirection.DOWNSTREAM, 1_100)
                .setJitter(100);

        // when: getting a key from Redis
        String value = jedis.get(KEY);

        // then: is able to retrieve data properly
        assertEquals(VALUE, value);
    }

    @Test
    public void cutRedisConnection() throws Exception {
        // Cut connection completely
        proxy.toxics().bandwidth("CUT_CONNECTION_DOWNSTREAM", ToxicDirection.DOWNSTREAM, 0);
        proxy.toxics().bandwidth("CUT_CONNECTION_UPSTREAM", ToxicDirection.UPSTREAM, 0);

        // Expect failure when the connection is cut
        assertThat(
                catchThrowable(() -> {
                    jedis.get(KEY);
                })
        )
                .as("fails when the connection is cut")
                .isInstanceOf(JedisConnectionException.class);

        // Restore connection
        proxy.toxics().get("CUT_CONNECTION_DOWNSTREAM").remove();
        proxy.toxics().get("CUT_CONNECTION_UPSTREAM").remove();
        jedis.close();

        // With the connection re-established, expect success
        assertThat(jedis.get(KEY))
                .as("access to the container works after re-establishing the connection")
                .isEqualTo(VALUE);
    }
}
