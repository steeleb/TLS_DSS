settings = {
  "overfit" : {
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
  },
  
  "simple" : { # this is terrible. Like really bad and only provides a single value, I think this is due to the regularization
    "hiddens": [10, 10, 10],
    "activations": ["tanh", "tanh", "tanh"],
    "learning_rate": 0.001,
    "random_seed": 57,
    "max_epochs": 1000,
    "batch_size": 64,
    "patience": 500,
    "dropout_rate": 0.05,
    "l1_reg": 0.1,
    "l2_reg": 0.1     
  },
    "three_ten" : { # same as simple, but with no regularization
    "hiddens": [10, 10, 10],
    "activations": ["tanh", "tanh", "tanh"],
    "learning_rate": 0.001,
    "random_seed": 57,
    "max_epochs": 1000,
    "batch_size": 64,
    "patience": 500,
    "dropout_rate": 0.1,
    "l1_reg": 0,
    "l2_reg": 0     
  },
    "three_ten_larger_eta" : { # same as simple, but with no regularization
    "hiddens": [10, 10, 10],
    "activations": ["tanh", "tanh", "tanh"],
    "learning_rate": 0.01,
    "random_seed": 57,
    "max_epochs": 1000,
    "batch_size": 64,
    "patience": 500,
    "dropout_rate": 0.1,
    "l1_reg": 0,
    "l2_reg": 0     
  },
  "five_ten" : {
    "hiddens": [10, 10, 10, 10, 10],
    "activations": ["tanh", "tanh", "tanh", "tanh", "tanh"],
    "learning_rate": 0.001,
    "random_seed": 57,
    "max_epochs": 2000,
    "batch_size": 64,
    "patience": 500,
    "dropout_rate": 0.1,
    "l1_reg": 0.0,
    "l2_reg": 0.0     
  },
  "five_ten_larger_eta" : {
    "hiddens": [10, 10, 10, 10, 10],
    "activations": ["tanh", "tanh", "tanh", "tanh", "tanh"],
    "learning_rate": 0.01,
    "random_seed": 57,
    "max_epochs": 2000,
    "batch_size": 64,
    "patience": 500,
    "dropout_rate": 0.1,
    "l1_reg": 0.0,
    "l2_reg": 0.0     
  },
    "five_fifteen_ten" : {
    "hiddens": [15, 10, 10, 10, 15],
    "activations": ["tanh", "tanh", "tanh", "tanh", "tanh"],
    "learning_rate": 0.001,
    "random_seed": 57,
    "max_epochs": 2000,
    "batch_size": 64,
    "patience": 500,
    "dropout_rate": 0.1,
    "l1_reg": 0.0,
    "l2_reg": 0.0     
  }
}
