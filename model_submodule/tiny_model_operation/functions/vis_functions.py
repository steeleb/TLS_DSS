import matplotlib.pyplot as plt


def create_scatter_plot(dataset_name, p_v_act, l_v_act, p_act, l_act):
    plt.scatter(p_act, l_act, color='red', label='Training')
    plt.scatter(p_v_act, l_v_act, color='blue', label='Validation')
    plt.xlabel('Predicted')
    plt.ylabel('Observed')
    plt.title(dataset_name)
    plt.legend()
    plt.show()

def plot_history_loss(history, title):
    plt.figure(figsize=(4,4))
    plt.plot(history.history["loss"], label="training")
    plt.plot(history.history["val_loss"], label="validation")
    plt.xlabel("Epoch")
    plt.ylabel("Loss")
    plt.legend()
    plt.title(title)
    plt.show()

def create_scatter_plot_test(dataset_name, predicted, actual):
    plt.scatter(predicted, actual, color='blue', label='Test')
    plt.xlabel('Predicted')
    plt.ylabel('Observed')
    plt.title(dataset_name)
    plt.legend()
    plt.show()

def ts_plot(y, y_hat, title):
    plt.figure(figsize=(4,4))
    plt.plot(y, label="Observed", color='blue')
    plt.plot(y_hat, label="Predicted", color='red')
    plt.xlabel("Time")
    plt.ylabel("Temperature")
    plt.legend()
    plt.title(title)
    plt.show()
