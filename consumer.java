// camel-k: language=java
// camel-k: dependency=camel-http
// camel-k: dependency=camel-file

import org.apache.camel.builder.RouteBuilder;

public class consumer extends RouteBuilder {
    @Override
    public void configure() throws Exception {

        // Poll a public API every minute for Bitcoin price updates
        from("timer:crypto-events?period=60000")
            .routeId("crypto-price-consumer")
            .log("📡 Fetching crypto price event...")
            .to("https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd")
            .convertBodyTo(String.class)
            .log("📬 Received event: ${body}")
            .log("✅ Event received at ${date:now:yyyy-MM-dd HH:mm:ss} - Bitcoin Price: ${body}");
    }
}
