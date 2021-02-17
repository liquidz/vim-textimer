export function getCurrentLine(denops: Denops): Promise<string> {
  return await denops.call("getline", ["."]);
}
