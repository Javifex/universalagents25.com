package com.universalagents25.app;

import java.net.URI;
import java.net.URISyntaxException;

public final class UrlPolicy {
    public static final String HOME = "https://universalagents25.com/";

    public enum Destination { INTERNAL, EXTERNAL, BLOCKED }

    private UrlPolicy() {}

    public static String retryUrl(String mainUrl) {
        return classify(mainUrl) == Destination.INTERNAL ? mainUrl : HOME;
    }

    public static Destination classify(String value) {
        if (value == null) return Destination.BLOCKED;
        for (int i = 0; i < value.length(); i++) {
            if (value.charAt(i) == '\\' || Character.isISOControl(value.charAt(i))) {
                return Destination.BLOCKED;
            }
        }

        final URI uri;
        try {
            uri = new URI(value);
        } catch (URISyntaxException error) {
            return Destination.BLOCKED;
        }

        String scheme = uri.getScheme();
        if ("mailto".equalsIgnoreCase(scheme) || "tel".equalsIgnoreCase(scheme)) {
            return uri.isOpaque() && !uri.getRawSchemeSpecificPart().isEmpty()
                    ? Destination.EXTERNAL : Destination.BLOCKED;
        }
        if (!"https".equalsIgnoreCase(scheme) || uri.isOpaque()
                || uri.getHost() == null || uri.getRawUserInfo() != null
                || uri.getRawAuthority().endsWith(":")) {
            return Destination.BLOCKED;
        }

        int port = uri.getPort();
        if (port == 0 || port < -1 || port > 65535) return Destination.BLOCKED;
        if ("universalagents25.com".equalsIgnoreCase(uri.getHost())) {
            return port == -1 || port == 443 ? Destination.INTERNAL : Destination.BLOCKED;
        }
        return Destination.EXTERNAL;
    }
}
