# npm publishing

Package: [`@userdefault/svg-importer`](https://www.npmjs.com/package/@userdefault/svg-importer)

## One-time setup

### 1. npm automation token

1. [npmjs.com/settings/~/tokens](https://www.npmjs.com/settings/~/tokens)
2. **Generate New Token** → Granular Access Token
3. Packages: `@userdefault/svg-importer` (Read and Write)
4. Copy the token (shown once)

### 2. Store in abra

```bash
abra set aesprite-svgimporter NPM_TOKEN
# paste token at hidden prompt (Touch ID)

# Optional: agent API key scoped to this project
abra keys new cursor-agent -p aesprite-svgimporter
export ABRA_KEY=abra_…   # prefix only in chat; store in your shell profile
```

### 3. Publish

```bash
cd /path/to/aesprite-svgimporter
npm run build
abra run aesprite-svgimporter -- npm publish --access public
```

Or with env injection if `NPM_TOKEN` is already in the project:

```bash
eval "$(abra env aesprite-svgimporter)" && npm publish --access public
```

## Install for users

```bash
npx @userdefault/svg-importer install
```

Then restart Aseprite → **File → Import SVG**.

## Version bumps

Sync version in:

- `package.json` (npm)
- `extracted/package.json` (Aseprite extension manifest)
- `CHANGELOG.md`

Then rebuild, commit, tag, and publish.
