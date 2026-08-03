const { PrismaClient } = require("@prisma/client");
const bcrypt = require("bcryptjs");
const p = new PrismaClient();
(async () => {
  const hash = await bcrypt.hash("123456", 10);
  const acc = await p.account.create({ data: { username: "user01", password: hash, status: "Active", idrole: 2 } });
  await p.user.create({ data: { fullname: "Test User", email: "user01@test.com", idaccount: acc.idaccount } });
  console.log("User created:", acc.username, "idrole:", acc.idrole);
  await p.$disconnect();
})();