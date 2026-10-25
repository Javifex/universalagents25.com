package com.universalagents25.app;

import static com.universalagents25.app.UrlPolicy.Destination.BLOCKED;
import static com.universalagents25.app.UrlPolicy.Destination.EXTERNAL;
import static com.universalagents25.app.UrlPolicy.Destination.INTERNAL;
import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class UrlPolicyTest {
    @Test public void retriesTheCurrentPageWithoutNavigatingToAnExternalResource() {
        String account = "https://universalagents25.com/cuenta.html?modo=login";
        assertEquals(account, UrlPolicy.retryUrl(account));
        for (String url : new String[] {
                null, "https://external.example/",
                "https://project.supabase.co/auth/v1/token", "javascript:alert(1)"
        }) {
            assertEquals(url, UrlPolicy.HOME, UrlPolicy.retryUrl(url));
        }
    }

    @Test public void permitsOnlyTheExactHttpsOriginInsideTheApp() {
        for (String url : new String[] {
                "https://universalagents25.com/",
                "HTTPS://UNIVERSALAGENTS25.COM/cuenta.html?modo=login#perfil",
                "https://universalagents25.com:443/cuenta.html"
        }) {
            assertEquals(url, INTERNAL, UrlPolicy.classify(url));
        }
    }

    @Test public void sendsOtherHttpsOriginsToTheBrowser() {
        for (String url : new String[] {
                "https://universalagents25.com.evil.test/",
                "https://evil-universalagents25.com/",
                "https://www.universalagents25.com/",
                "https://accounts.example.com:444/",
                "https://universalagents25.com./"
        }) {
            assertEquals(url, EXTERNAL, UrlPolicy.classify(url));
        }
    }

    @Test public void blocksUserInfoAndEncodedOrConfusableHosts() {
        for (String url : new String[] {
                "https://universalagents25.com@evil.test/",
                "https://user:password@universalagents25.com/",
                "https://user@external.example/",
                "https://universalagents25%2ecom/",
                "https://universalagents25.com%40evil.test/",
                "https://universalagents25.c\u043Em/",
                "https://universalagents25.com\\@evil.test/"
        }) {
            assertEquals(url, BLOCKED, UrlPolicy.classify(url));
        }
    }

    @Test public void blocksAlternateInternalPortsAndInvalidPorts() {
        for (String url : new String[] {
                "https://universalagents25.com:444/",
                "https://universalagents25.com:/",
                "https://universalagents25.com:0/",
                "https://example.com:65536/",
                "https://example.com:-1/"
        }) {
            assertEquals(url, BLOCKED, UrlPolicy.classify(url));
        }
    }

    @Test public void permitsOnlyOpaqueMailAndPhoneLinks() {
        assertEquals(EXTERNAL, UrlPolicy.classify("mailto:soporte@universalagents25.com"));
        assertEquals(EXTERNAL, UrlPolicy.classify("tel:+573001234567"));
        assertEquals(BLOCKED, UrlPolicy.classify("mailto:"));
        assertEquals(BLOCKED, UrlPolicy.classify("tel:"));
        assertEquals(BLOCKED, UrlPolicy.classify("mailto://example.com"));
        assertEquals(BLOCKED, UrlPolicy.classify("tel://1234"));
    }

    @Test public void blocksUnsafeSchemesMalformedUrlsAndControls() {
        for (String url : new String[] {
                "http://universalagents25.com/",
                "javascript:alert(1)", "data:text/html,hello", "file:///etc/passwd",
                "content://example/path", "intent://example/#Intent;end",
                "https:universalagents25.com", "https:///cuenta.html", "/cuenta.html",
                "https://universalagents25.com/\n", "https://example.com/\u007F",
                "https://[invalid", "", " "
        }) {
            assertEquals(url, BLOCKED, UrlPolicy.classify(url));
        }
        assertEquals(BLOCKED, UrlPolicy.classify(null));
    }
}
