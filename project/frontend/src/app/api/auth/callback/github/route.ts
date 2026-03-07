import { NextRequest, NextResponse } from 'next/server';

// API_URL is a private server-side var (EC2 HTTP address). Falls back to NEXT_PUBLIC_API_URL for local dev.
const BACKEND_URL = process.env.API_URL || process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';

// Derive the correct public base URL — Amplify SSR compute may report an
// internal hostname in request.url, so we prefer NEXT_PUBLIC_APP_URL or the
// forwarded host header over request.url.
function getBaseUrl(request: NextRequest): string {
  if (process.env.NEXT_PUBLIC_APP_URL) {
    return process.env.NEXT_PUBLIC_APP_URL.replace(/\/$/, '');
  }
  const forwardedHost = request.headers.get('x-forwarded-host');
  const host = forwardedHost || request.headers.get('host') || 'localhost:3000';
  const proto = request.headers.get('x-forwarded-proto') || 'https';
  return `${proto}://${host}`;
}

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams;
  const code = searchParams.get('code');
  const error = searchParams.get('error');
  const baseUrl = getBaseUrl(request);

  if (error) {
    console.error('GitHub OAuth error:', error);
    return NextResponse.redirect(`${baseUrl}/dashboard?error=github_auth_failed`);
  }

  if (!code) {
    return NextResponse.redirect(`${baseUrl}/dashboard?error=no_code`);
  }

  // GitHub App sends installation_id alongside code
  const installationId = searchParams.get('installation_id');
  // state carries the existing JWT when linking GitHub to a Google-logged-in user
  const state = searchParams.get('state');

  try {
    // Send code + installation_id to backend to exchange for tokens
    const tokenResponse = await fetch(`${BACKEND_URL}/api/auth/github/callback`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        code,
        installation_id: installationId ? parseInt(installationId, 10) : null,
        link_token: state || undefined,
      }),
    });

    if (!tokenResponse.ok) {
      const errorData = await tokenResponse.json();
      console.error('Backend OAuth error:', errorData);
      return NextResponse.redirect(`${baseUrl}/dashboard?error=token_exchange_failed`);
    }

    const tokenData = await tokenResponse.json();
    const accessToken = tokenData.access_token;

    // Redirect to dashboard with token in URL (it will be stored in localStorage)
    return NextResponse.redirect(`${baseUrl}/dashboard?github=connected&token=${accessToken}`);
  } catch (err) {
    console.error('GitHub OAuth callback error:', err);
    return NextResponse.redirect(`${baseUrl}/dashboard?error=callback_failed`);
  }
}
