export interface User {
  name: string;
}

export interface Notification {
  user: User;
  content: string;
}
