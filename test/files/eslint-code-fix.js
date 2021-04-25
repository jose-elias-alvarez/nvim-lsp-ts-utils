export const greetUser = (user) => {
  if (typeof user.name == "string") {
    console.log(`Hi ${user.name}!`);
  }
};
