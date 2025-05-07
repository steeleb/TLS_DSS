settings = {
  "leaky_super_overfit" : {
    "hiddens": [50, 30, 30, 30, 30, 30, 50],
    "activations": ["tanh", "tanh", "tanh", "tanh", "tanh", "tanh", "tanh"],
    "learning_rate": 0.001,
    "random_seed": 57,
    "max_epochs": 1000,
    "batch_size": 128,
    "patience": 500,
    "dropout_rate": 0,
    "l1_reg": 0.0,
    "l2_reg": 0.0     
  }
}
