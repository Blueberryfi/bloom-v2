import { defineConfig } from "@wagmi/cli";
import { foundry } from "@wagmi/cli/plugins";
 
export default defineConfig({
  out: "abis/BloomPool.ts",
  plugins: [
    foundry({
      project: "./",
      include: ["BloomPool.sol/**"]
    }),
  ],
});