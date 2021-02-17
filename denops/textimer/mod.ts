import { Denops } from "https://deno.land/x/denops@v0.5/denops.ts";
import { getCurrentLine } from "./vim.ts";

Denops.start(async function (denops: Denops): Promise<void> {
  denops.extendDispatcher({
    async menu(): Promise<unknown> {
      console.log("kiteruyo");
      return await Promise.resolve(true);
    },
  });

  await denops.command(
    `command! TextimerMenu call denops#notify("${denops.name}", "menu", [])`,
  );
});
