/**
 * Meta передаёт query с точками: hub.mode, hub.verify_token, hub.challenge.
 * Express/Nest может отдавать их плоско, вложенным hub.* или только в originalUrl.
 */
export interface MetaHubVerifyQuery {
  mode?: string;
  verifyToken?: string;
  challenge?: string;
}

export function parseMetaHubVerifyQuery(
  query: Record<string, unknown>,
  rawUrl?: string,
): MetaHubVerifyQuery {
  const fromQuery = parseFromQueryObject(query);
  const fromUrl = rawUrl ? parseFromUrl(rawUrl) : {};

  return {
    mode: fromQuery.mode ?? fromUrl.mode,
    verifyToken: fromQuery.verifyToken ?? fromUrl.verifyToken,
    challenge: fromQuery.challenge ?? fromUrl.challenge,
  };
}

function parseFromQueryObject(query: Record<string, unknown>): MetaHubVerifyQuery {
  const hub =
    typeof query.hub === 'object' && query.hub !== null
      ? (query.hub as Record<string, unknown>)
      : undefined;

  return {
    mode:
      stringOrUndefined(query['hub.mode']) ?? stringOrUndefined(hub?.mode),
    verifyToken:
      stringOrUndefined(query['hub.verify_token']) ??
      stringOrUndefined(hub?.verify_token),
    challenge:
      stringOrUndefined(query['hub.challenge']) ??
      stringOrUndefined(hub?.challenge),
  };
}

function parseFromUrl(rawUrl: string): MetaHubVerifyQuery {
  const qIndex = rawUrl.indexOf('?');
  if (qIndex < 0) {
    return {};
  }

  const params = new URLSearchParams(rawUrl.slice(qIndex + 1));
  return {
    mode: stringOrUndefined(params.get('hub.mode')),
    verifyToken: stringOrUndefined(params.get('hub.verify_token')),
    challenge: stringOrUndefined(params.get('hub.challenge')),
  };
}

function stringOrUndefined(value: unknown): string | undefined {
  if (value === null || value === undefined) return undefined;
  const trimmed = String(value).trim();
  return trimmed.length > 0 ? trimmed : undefined;
}
