# Algorithmic Trading with Neural Nets

## Overview
This project involved using R to implement a toy algorithmic trading system. Using neuralnet and quantmod packages, we trained an MLP
on time series data containing daily stock prices for Tesla stock. Our goal was to make predictions on future prices, which would be 
used to form the basis of trading rules. The system would implement these trading rules based on the accuracy of our predictions. 

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
as data on the stock volume and moving averages. We would be wanting to train on a series of day's data, and then predict the following
day's high and low price. 

## Model Choice & Training

We were experimenting with neural nets on this project. We wanted to train on 3 days worth of prices, to make a prediction for the 4th 
day's high and low prices. 

![](https://github.com/d-smit/algorithmic-trading-with-neural-networks/tree/master/plots/nn_1.png)
