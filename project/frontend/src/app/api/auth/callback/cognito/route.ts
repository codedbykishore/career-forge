import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.API_URL || process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';

// Amplify SSR compute may report an internal hostname in request.url,
// so we prefer NEXT_PUBLIC_APP_URL or the forwarded host header.
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
    console.error('Cognito OAuth error:', error, searchParams.get('error_description'));
    return NextResponse.redirect(`${baseUrl}/login?error=cognito_auth_failed`);
  }

  if (!code) {
    return NextResponse.redirect(`${baseUrl}/login?error=no_code`);
  }

  try {
    const tokenResponse = await fetch(`${BACKEND_URL}/api/auth/cognito/callback`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ code }),
    });

    if (!tokenResponse.ok) {
      const errorData = await tokenResponse.json();
      console.error('Backend Cognito callback error:', errorData);
      return NextResponse.redirect(`${baseUrl}/login?error=token_exchange_failed`);
    }

    const tokenData = await tokenResponse.json();
    const accessToken = tokenData.access_token;

    // Store token via redirect — dashboard's useEffect picks it up from query params
    return NextResponse.redirect(`${baseUrl}/dashboard?google=connected&token=${accessToken}`);
  } catch (err) {
    console.error('Cognito callback error:', err);
    return NextResponse.redirect(`${baseUrl}/login?error=callback_failed`);
  }
}
