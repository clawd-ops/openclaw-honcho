import { describe, expect, it } from "vitest";
import { honchoConfigSchema } from "../config.js";

describe("honchoConfigSchema", () => {
  it("defaults canonicalPeerMap to an empty object", () => {
    expect(honchoConfigSchema.parse({}).canonicalPeerMap).toEqual({});
  });

  it("parses non-empty canonical peer mappings", () => {
    expect(
      honchoConfigSchema.parse({
        canonicalPeerMap: {
          owner: "rob",
          "uuid_d7a458ea-bf8f-4831-8030-d80bd4529cb4": "rob",
        },
      }).canonicalPeerMap,
    ).toEqual({
      owner: "rob",
      "uuid_d7a458ea-bf8f-4831-8030-d80bd4529cb4": "rob",
    });
  });

  it("ignores invalid canonical peer map entries", () => {
    expect(
      honchoConfigSchema.parse({
        canonicalPeerMap: {
          owner: "rob",
          empty: "",
          number: 123,
        },
      }).canonicalPeerMap,
    ).toEqual({ owner: "rob" });
  });
});
