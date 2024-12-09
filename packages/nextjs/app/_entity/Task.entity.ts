export interface ITask {
  taskID: bigint;
  name: string;
  description: string;
  reward: bigint;
  responsible: string;
  rules: string;
  completed: boolean;
}

export interface ItaskCompleted {
  taskID: bigint;
  proof: string;
  verifier: string;
  verified: boolean;
}