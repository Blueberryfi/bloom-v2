import { defineConfig } from "@wagmi/cli";
import { foundry } from "@wagmi/cli/plugins";
 
export default defineConfig({
  out: "abis/Tby.ts",
  plugins: [
    foundry({
      project: "./",
      include: ["Tby.sol/**"]
    }),
  ],
});