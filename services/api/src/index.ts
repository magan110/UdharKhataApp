export default {
  fetch(): Response {
    return Response.json(
      { error: { code: 'NOT_IMPLEMENTED', message: 'API setup in progress' } },
      { status: 503, headers: { 'Cache-Control': 'no-store' } },
    );
  },
} satisfies ExportedHandler;
