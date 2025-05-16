# high level modules
import imp
# ml/ai modules
import tensorflow as tf
# Let's import some different things we will use to build the neural network
from tensorflow.keras import Model
from tensorflow.keras.layers import Dense, Input, Dropout, Softmax

def build_model(x_train, x_target, settings):
  # create input layer
  input_layer = tf.keras.layers.Input(shape=x_train.shape[1:])
  
  # # create hidden layers each with specific number of nodes
  # assert len(settings["hiddens"]) == len(
  #   settings["activations"]
  # ), "hiddens and activations settings must be the same length."
  
  # add dropout layer
  layers = tf.keras.layers.Dropout(rate=settings["dropout_rate"])(input_layer)
  
  for hidden, activation in zip(settings["hiddens"], settings["activations"]):
    layers = tf.keras.layers.Dense(
      units=hidden,
      activation=activation,
      use_bias=True,
      kernel_regularizer=tf.keras.regularizers.l1_l2(l1=settings["l1_reg"], l2=settings["l2_reg"]),
      bias_initializer=tf.keras.initializers.RandomNormal(seed=settings["random_seed"]),
      kernel_initializer=tf.keras.initializers.RandomNormal(seed=settings["random_seed"]),
      )(layers)
  
  # create output layer - two units for two outputs
  output_layer = tf.keras.layers.Dense(
    units=2,
    activation="linear",
    use_bias=True,
    bias_initializer=tf.keras.initializers.RandomNormal(seed=settings["random_seed"] + 1),
    kernel_initializer=tf.keras.initializers.RandomNormal(seed=settings["random_seed"] + 2),
  )(layers)
  
  # construct the model
  model = tf.keras.Model(inputs=input_layer, outputs=output_layer)
  model.summary()
  
  return model


def compile_model(model, settings):
  model.compile(
      optimizer=tf.keras.optimizers.Adam(
        learning_rate=settings["learning_rate"],
        ),
      loss=tf.keras.losses.MeanSquaredError()
  )
  return model


def compile_model_mae(model, settings):
  model.compile(
      optimizer=tf.keras.optimizers.Adam(
        learning_rate=settings["learning_rate"],
        ),
      loss=tf.keras.losses.MeanAbsoluteError()
  )
  return model

def weighted_mse_loss(y_true, y_pred):
    weights = tf.constant([0.7, 0.3])
    squared_difference = tf.square(y_true - y_pred)
    weighted_squared_difference = squared_difference * weights
    return tf.reduce_mean(weighted_squared_difference)

def weighted_mae_loss(y_true, y_pred):
    weights = tf.constant([0.6, 0.4])
    abs_difference = tf.abs(y_true - y_pred)
    weighted_abs_difference = abs_difference * weights
    return tf.reduce_mean(weighted_abs_difference)

def compile_weighted_model(model, settings):
  model.compile(
      optimizer=tf.keras.optimizers.Adam(
        learning_rate=settings["learning_rate"],
        ),
      loss=weighted_mse_loss
  )
  return model

def compile_wtd_mae_model(model, settings):
  model.compile(
      optimizer=tf.keras.optimizers.Adam(
        learning_rate=settings["learning_rate"],
        ),
      loss=weighted_mae_loss
  )
  return model


