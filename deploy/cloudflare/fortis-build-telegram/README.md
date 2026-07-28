# Fortis build Telegram Worker

Cloudflare Worker proxy for Fortis deploy notifications:

```text
Dev VM -> Cloudflare Worker -> Telegram topic 370
```

This avoids direct `api.telegram.org` calls from the Russian dev VM.

## Secrets

Set secrets in Cloudflare, never in Git:

```bash
npx wrangler secret put TELEGRAM_BOT_TOKEN
npx wrangler secret put DEPLOY_WEBHOOK_SECRET
```

The VM stores only the full `DEPLOY_NOTIFY_WEBHOOK_URL`:

```env
DEPLOY_NOTIFY_WEBHOOK_URL=https://fortis-build-telegram.galyamdin.workers.dev/deploy/<DEPLOY_WEBHOOK_SECRET>
```

## Commands

```bash
npm test
npx wrangler deploy --dry-run
npx wrangler deploy
```
