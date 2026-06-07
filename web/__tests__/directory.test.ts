import { displayUser, displaySite, Directory } from "@/lib/directory";

const dir: Directory = {
  users: new Map([["u1", { name: "Paul Mbarga" }]]),
  sites: new Map([["s1", { name: "Douala-Nord" }]]),
};

describe("displayUser", () => {
  it("renvoie le nom quand l'utilisateur est connu", () => {
    expect(displayUser("u1", dir)).toBe("Paul Mbarga");
  });
  it("renvoie l'ID en repli quand l'utilisateur est inconnu", () => {
    expect(displayUser("u404", dir)).toBe("u404");
  });
});

describe("displaySite", () => {
  it("renvoie le nom quand le site est connu", () => {
    expect(displaySite("s1", dir)).toBe("Douala-Nord");
  });
  it("renvoie l'ID en repli quand le site est inconnu", () => {
    expect(displaySite("s404", dir)).toBe("s404");
  });
});
