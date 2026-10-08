// Klient HTTP aplikacji. Komponenty dostają go jako zależność; w testach fetch jest podmieniony.

export class ApiError extends Error {
  constructor(status, body) {
    super(`API ${status}`);
    this.name = 'ApiError';
    this.status = status;
    this.body = body;
  }
}

export function createApiClient(fetchImpl) {
  async function getJson(path) {
    const response = await fetchImpl(path, { headers: { accept: 'application/json' } });
    const body = await response.json();
    if (!response.ok) throw new ApiError(response.status, body);
    return body;
  }

  return {
    listNotes: () => getJson('/notes'),
  };
}
