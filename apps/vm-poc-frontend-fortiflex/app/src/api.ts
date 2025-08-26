// frontend/src/api.ts
export async function deploy(payload: any) {
  const r = await fetch("/api/deploy", {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify(payload),
  });
  if (!r.ok) throw new Error(await r.text());
  return r.json();
}