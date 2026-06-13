import { displayUser, displaySite, clerkDisplayName, Directory } from "@/lib/directory";

const dir: Directory = {
  users: new Map([["u1", { name: "Paul Mbarga" }]]),
  sites: new Map([["s1", { name: "Douala-Nord", geo: { lat: 4.0511, lng: 9.7679 }, radiusMeters: 500 }]]),
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
  it("affiche 'Sans site' quand le siteId est vide (pointage sans tâche)", () => {
    expect(displaySite("", dir)).toBe("Sans site");
  });
});

describe("clerkDisplayName", () => {
  const base = { id: "user_x", firstName: null, lastName: null, username: null,
    primaryEmailAddressId: null, emailAddresses: [] };

  it("préfère prénom + nom", () => {
    expect(clerkDisplayName({ ...base, firstName: "Francis", lastName: "Kago" })).toBe("Francis Kago");
  });
  it("accepte un seul des deux (prénom ou nom)", () => {
    expect(clerkDisplayName({ ...base, firstName: "Francis" })).toBe("Francis");
    expect(clerkDisplayName({ ...base, lastName: "Kago" })).toBe("Kago");
  });
  it("retombe sur le username quand pas de nom", () => {
    expect(clerkDisplayName({ ...base, username: "fkago" })).toBe("fkago");
  });
  it("retombe sur l'email principal quand pas de nom ni username", () => {
    expect(clerkDisplayName({
      ...base,
      primaryEmailAddressId: "e2",
      emailAddresses: [
        { id: "e1", emailAddress: "secondaire@x.com" },
        { id: "e2", emailAddress: "principal@x.com" },
      ],
    })).toBe("principal@x.com");
  });
  it("prend le premier email si aucun n'est marqué principal", () => {
    expect(clerkDisplayName({
      ...base,
      emailAddresses: [{ id: "e1", emailAddress: "a@x.com" }],
    })).toBe("a@x.com");
  });
  it("retombe sur l'id en dernier recours", () => {
    expect(clerkDisplayName(base)).toBe("user_x");
  });
});
