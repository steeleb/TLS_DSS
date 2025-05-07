import pickle
import numpy as np
import tensorflow as tf
from sklearn.metrics import mean_squared_error, mean_absolute_error, mean_absolute_percentage_error
import os
from tensorflow import keras

def save_to_pickle(obj, filepath):
    """
    Save an object to a pickle file.
    
    Parameters:
    obj (object): The object to be saved.
    filepath (str): The filepath to save the object to.
    
    Returns:
    None
    """
    with open(filepath, 'wb') as f:
        pickle.dump(obj, f)

def save_keras_model(model, filepath):
    """
    Save a Keras model to a file.
    
    Parameters:
    model (keras.Model): The Keras model to be saved.
    filepath (str): The filepath to save the model to.
    
    Returns:
    None
    """
    model.save(filepath)

def load_pickle_file(file_name, file_path):
    """
    Load a pickle file from a given file path and file name.

    Args:
    file_path (str): The path to the directory containing the pickle file.
    file_name (str): The name of the pickle file.

    Returns:
    any: The object stored in the pickle file.
    """
    with open(os.path.join(file_path, file_name), 'rb') as f:
        return pickle.load(f)

def weighted_mse_loss(y_true, y_pred):
    weights = tf.constant([0.6, 0.4])
    squared_difference = tf.square(y_true - y_pred)
    weighted_squared_difference = squared_difference * weights
    return tf.reduce_mean(weighted_squared_difference)

def weighted_mae_loss(y_true, y_pred):
    weights = tf.constant([0.6, 0.4])
    abs_difference = tf.abs(y_true - y_pred)
    weighted_abs_difference = abs_difference * weights
    return tf.reduce_mean(weighted_abs_difference)

def load_keras_model_custom_loss(file_name, file_path):
    """
    Load a Keras model from a file with a custom loss function.
    
    Parameters:
    file_path (str): The path to the directory containing the pikerasckle file.
    file_name (str): The name of the keras file.

    Returns:
    keras.Model: The Keras model loaded from the file.
    """
    return keras.models.load_model(os.path.join(file_path, file_name), custom_objects={"weighted_mse_loss": weighted_mse_loss})

def load_keras_model_wtd_mae_loss(file_name, file_path):
    """
    Load a Keras model from a file with a custom loss function.
    
    Parameters:
    file_path (str): The path to the directory containing the pikerasckle file.
    file_name (str): The name of the keras file.

    Returns:
    keras.Model: The Keras model loaded from the file.
    """
    return keras.models.load_model(os.path.join(file_path, file_name), custom_objects={"weighted_mae_loss": weighted_mae_loss})

def get_features_labels(train_dfs, val_dfs):
  # grab the values we want to predict
  labels = np.array(train_dfs['value'])
  val_labels = np.array(val_dfs['value'])
  
  # and remove the labels from the dataset containing the feature set
  features = train_dfs.drop(['value', 'feature', 'date'], axis=1)
  val_features = val_dfs.drop(['value', 'feature', 'date'], axis=1)
  
  return features, labels, val_features, val_labels

def twotemp_labels_features(train_dfs, val_dfs):
  labels = np.array(train_dfs[['mean_1m_temp_degC', 'mean_0_5m_temp_degC']])
  # grab the values we want to predict
  val_labels = np.array(val_dfs[['mean_1m_temp_degC', 'mean_0_5m_temp_degC']])
  
  # and remove the labels from the dataset containing the feature set
  features = train_dfs.drop(['mean_1m_temp_degC', 'mean_0_5m_temp_degC', 'date'], axis=1)
  val_features = val_dfs.drop(['mean_1m_temp_degC', 'mean_0_5m_temp_degC', 'date'], axis=1)
  
  return features, labels, val_features, val_labels

def twotemp_labels_features_withtest(train_dfs, val_dfs):
  labels = np.array(train_dfs[['mean_1m_temp_degC', 'mean_0_5m_temp_degC']])
  # grab the values we want to predict
  val_labels = np.array(val_dfs[['mean_1m_temp_degC', 'mean_0_5m_temp_degC']])
  
  # and remove the labels from the dataset containing the feature set
  features = train_dfs.drop(['Unnamed: 0', 'mean_1m_temp_degC', 'mean_0_5m_temp_degC', 'date'], axis=1)
  val_features = val_dfs.drop(['mean_1m_temp_degC', 'mean_0_5m_temp_degC', 'date'], axis=1)
  
  return features, labels, val_features, val_labels


def get_features_labels_test(test_df):
  # grab the values we want to predict
  labels = np.array(test_df['value'])
  
  # and remove the labels from the dataset containing the feature set
  features = test_df.drop(['value', 'feature', 'date'], axis=1)
  
  return features, labels


def twotemp_labels_features_test(test_df):
  labels = np.array(test_df[['mean_1m_temp_degC', 'mean_0_5m_temp_degC']])
  
  # and remove the labels from the dataset containing the feature set
  features = test_df.drop(['mean_1m_temp_degC', 'mean_0_5m_temp_degC', 'date'], axis=1)
  
  return features, labels


def calculate_vals(transformed_val, mean, std):
  actual_val = (transformed_val * std) + mean
  return actual_val


def predict_values(model, features, val_features, labels, val_labels, t_mean, t_std):
    pred = model.predict(features)
    val = model.predict(val_features)
    p_act = calculate_vals(pred, t_mean, t_std)
    l_act = calculate_vals(labels, t_mean, t_std)
    p_v_act = calculate_vals(val, t_mean, t_std)
    l_v_act = calculate_vals(val_labels, t_mean, t_std)
    return p_act, l_act, p_v_act, l_v_act

def predict_2_values(model, features, val_features, labels, val_labels, 
                    t_mean_1m, t_mean_05m, t_std_1m, t_std_05m):
    # predict values using training features
    pred = model.predict(features)
    # and the validation features
    val = model.predict(val_features)
    # calculate the actual values from the training features
    p_train_1m = [calculate_vals(v, t_mean_1m, t_std_1m) for v in [p[0] for p in pred]]
    p_train_05m = [calculate_vals(v, t_mean_05m, t_std_05m) for v in [p[1] for p in pred]]
    # back-calculate the label values from the training labels
    act_train_1m = [calculate_vals(v, t_mean_1m, t_std_1m) for v in [l[0] for l in labels]]
    act_train_05m = [calculate_vals(v, t_mean_05m, t_std_05m) for v in [l[1] for l in labels]]
    # calculate the actual values from the validation features
    p_val_1m = [calculate_vals(v, t_mean_1m, t_std_1m) for v in [p[0] for p in val]]
    p_val_05m = [calculate_vals(v, t_mean_05m, t_std_05m) for v in [p[1] for p in val]]
    ## back-calculate the label values from the validation labels
    act_val_1m = [calculate_vals(v, t_mean_1m, t_std_1m) for v in [l[0] for l in val_labels]]
    act_val_05m = [calculate_vals(v, t_mean_05m, t_std_05m) for v in [l[1] for l in val_labels]]
    return p_train_1m, p_train_05m, act_train_1m, act_train_05m, p_val_1m, p_val_05m, act_val_1m, act_val_05m

def predict_values_test(model, features, t_mean, t_std):
    pred = model.predict(features)
    p_act = calculate_vals(pred, t_mean, t_std)
    return p_act

def predict_2_values_test(model, features, t_mean_1m, t_mean_05m, t_std_1m, t_std_05m):
    # predict values using training features
    pred = model.predict(features)
    # calculate the actual values from the training features
    p_test_1m = [calculate_vals(v, t_mean_1m, t_std_1m) for v in [p[0] for p in pred]]
    p_test_05m = [calculate_vals(v, t_mean_05m, t_std_05m) for v in [p[1] for p in pred]]
    return p_test_1m, p_test_05m

def print_error_metrics(dataset_num, l_act, p_act, l_v_act, p_v_act):
    t_mse = mean_squared_error(l_act, p_act)
    t_mae = mean_absolute_error(l_act, p_act)
    v_mse = mean_squared_error(l_v_act, p_v_act)
    v_mae = mean_absolute_error(l_v_act, p_v_act)
    print("DATASET", dataset_num)
    print("Mean Squared Error for Training Dataset", dataset_num, ":", t_mse)
    print("Mean Absolute Error for Training Dataset", dataset_num, ":", t_mae)
    print("Mean Squared Error for Validation Dataset", dataset_num, ":", v_mse)
    print("Mean Absolute Error for Validation Dataset", dataset_num, ":", v_mae)
    print(' ')

def return_test_error_metrics(actual, predicted):
    mse = mean_squared_error(actual, predicted)
    mae = mean_absolute_error(actual, predicted)
    rmse = np.sqrt(mse)
    mape = mean_absolute_percentage_error(actual, predicted)
    print("Test Datset Error Metrics:")
    print("Mean Squared Error:", mse)
    print("Mean Absolute Error:", mae)
    print("Root Mean Squared Error:", rmse)
    print("Mean Absolute Percentage Error:", mape)
    return mse, mae, rmse, mape