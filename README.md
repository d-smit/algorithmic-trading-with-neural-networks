# Algorithmic Trading with Neural Nets

## Overview
This project involved using R to implement a toy algorithmic trading system. Using ```neuralnet``` and ```quantmod``` packages, we trained an MLP
on time series data containing daily Tesla stock prices. Our goal was to make predictions on future prices, which would be 
used to form the basis of trading rules. These rules would formulate a trading system which operated on the accuracy of our predictions. 

## Implementation

We used quantmod to retrieve our time series data. 

```
library(quantmod)

stocks <- c('TSLA')

data <- getSymbols(stocks,
                   src="yahoo",
                   from="2016-01-01",
                   to="2018-01-01",
                   env=NULL)
                   
 ```
The getSymbols function allows financial data of a range of stocks to be accessed by downloading from financial archives. We choose 
Tesla stock data, retrieved from Yahoo Finance.  We chose 2 years worth of low, high, opening, closing and adjusted prices, as well
as overall trend data and moving averages. We would be wanting to train on three days worth of data, and then predict the following
day's high and low price, based on the previous day's performance. To build our training set in this way, we wanted to "lag" each input variable. 

```
lag_matrix <- data.frame(y0=HI,
                         y1=LO,
                         x0=OP
                         x1=Lag(as.numeric(OP), 1),
                         x2=Lag(as.numeric(HI), 1),
                         x3=Lag(as.numeric(LO), 1), 
                         x4=Lag(as.numeric(AD), 1),
                         x5=Lag(as.numeric(RSI), 1),
                         x6=Lag(as.numeric(SM10), 1),
                         x7=Lag(as.numeric(EM10), 1))
```

We can see a sample training set made above. ```y0``` and ```y1``` represented our output targets. The current day's high and low price. The ```x``` predictor variables were our model inputs, and represented the previous days performance data, as well as the current day's opening price. The lag above only shows a single day before; in our actual training set we were considering three days worth of stock performance. 

## Model Choice & Training

We were experimenting with neural nets on this project. We wanted to train on 3 days worth of prices, to make a prediction for the 4th 
day's high and low prices. We created our architecture using the ```neuralnet``` package:
```
forecast <- neuralnet(as.formula(HI + LO ~ .), 
                     train,
                     hidden = c(150,100),
                     stepmax=1e+06,
                     threshold=0.01)
```

This created a simple MLP with hidden layers of 150 and 100 nodes respectively. After setting our target variables as ```HI``` and ```LO``` prices, we were ready to begin training. We can visualise the training process below:

![](/plots/nn_1.png)

We trained on 20 months worth of data. As shown, over this period, we were training on three days worth of stock information in order to predict the fourth's high and low price. . 

## Testing 

We had previously held back 4 months worth of Tesla stock data. Using the same 4 day train/test split as above, we moved our sliding window through the 4 month period by day, providing daily predictions across the 4 months. 

We then wanted to design our trading system. This trading system would operate over the same 4 months, based on our daily high and low predictions. The system would rely on criteria which depended on our predictions, the actual stock performance over the testing period, and overall trends in the share price. We can see our trading rules below. 

## Trading Rules 

We wanted to make buy, sell or hold decisions based on our predictions for low and high prices. If we had predicted the low price within an accurate margin, we would buy, and similarly for high prices and selling. By starting with $10,000 capital, we implemented this system based on our predictions for the 4 month testing period. 

![](/plots/nn_rules.png)

Note: for buying, the actual price and prediction refers to the low price and prediction. For selling conditions, this refers to the high price and prediction. 

We can visualise our low and high price predictions vs the actual below. 

## Model Fitting 

The high volatility in the Tesla share price resulted in some overfitting taking place. We can see the actual low and high prices, against our predictions, over the 4 month testing period below. 

![](/plots/nn_act2.png)

As our trading rules relied on accurate predictions, levels of overfitting would impact the frequency of our trading activity. 

## Trading Activity

We can visualise the decisions made by our trading system below. The below plot shows are low and high price predictions, and where they triggered buy and sell decisions. We can also see the moving average to indicate the general trend of the stock. 

![](/plots/nn_act3.png)

We can see that trades are more frequently made during the period of upwards trend in the first 50 days. The system requires both accurate low price predictions and a strong upwards trend signal, indicated by the price position relative to the moving average, before buying. In contrast, the system sold the moment the high price prediction was accurate. This created a conservative trading system, which was tentative about entering the trade, and exited the moment it was profitable. It became less likely to trade during the downwards trend. This was also due to increased overfitting during this unstable period. 

Overall, only 18 trades were made over the 4 month period. However, a total profit of 56% was achieved. With Tesla being a highly volatile stock, the conservative style of the trading system gave optimal performance. 
