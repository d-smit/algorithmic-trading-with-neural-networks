library(quantmod)
library(neuralnet)
library(robustHD)
library(automultinomial)
library(TTR)
library(forecast)
library(Metrics)
library(DMwR)
library(dplyr)
library(ggplot2)
options(scipen = 10, digits=4)

stocks <- c('TSLA')

stock <-getSymbols(stocks,
                   src="yahoo",
                   from="2016-01-01",
                   to="2018-01-01",
                   env=NULL)

OP <- coredata(stock[,1])
HI <- coredata(stock[,2])
LO <- coredata(stock[,3])
CL <- coredata(stock[,4])
VO <- coredata(stock[,5])
AD <- coredata(stock[,6])
EM10 <- EMA(AD, 10)
EM30 <- EMA(AD, 30)
SM10 <- SMA(LO, 10)      # Used as part of trading rules
SM10Hi <- SMA(HI, 10)    # and comparison methods.
SM30 <- SMA(AD, 30)
RSI10 <- RSI(AD, 10)

# Make lagged data frame of all inputs minus one. Add todays HI and LO as target variables. 

lag_matrix <- data.frame(y1=HI,
                         y2=LO,
                         x1=Lag(as.numeric(OP), 1),
                         x2=Lag(as.numeric(OP), 2),
                         x3=Lag(as.numeric(OP), 3),
                         x4=Lag(as.numeric(HI), 1),
                         x5=Lag(as.numeric(HI), 2),
                         x6=Lag(as.numeric(HI), 3),
                         x7=Lag(as.numeric(LO), 1),
                         x8=Lag(as.numeric(LO), 2),
                         x9=Lag(as.numeric(LO), 3), 
                         x10=Lag(as.numeric(AD), 1),
                         x11=Lag(as.numeric(AD), 2),
                         x12=Lag(as.numeric(AD), 3),
                         x13=Lag(as.numeric(EM10), 1),
                         x14=Lag(as.numeric(EM30), 1),
                         x15=Lag(as.numeric(SM10), 1),
                         x16=Lag(as.numeric(SM10Hi), 1),
                         x17=Lag(as.numeric(RSI10), 1),
                         x18=OP);lag_matrix                 # Using the target day's open price to inform the trading system

colnames(lag_matrix) <- c('HI', 'LO', sprintf('Input%s', seq(1, (ncol(lag_matrix) - 2))))
lag_matrix <- ts(lag_matrix)
lag_matrix <- na.omit(lag_matrix)

# Scaling and getting variables to unscale later

scaled_matrix <- scale(lag_matrix, scale = TRUE, center = TRUE)
scale_parameters <- attributes(scaled_matrix);scale_parameters

# Splitting data 

split = 0.75
index <- round((split)*nrow(scaled_matrix));index
train <- scaled_matrix[1:index,];train
test <- scaled_matrix[index:nrow(scaled_matrix),];test

# Neural network 

forecast <- neuralnet(as.formula(HI + LO ~ .), 
                     train,
                     hidden = c(15,15),
                     stepmax=1e+06,
                     threshold=0.01)

# Training

train_perf <-forecast$net.result[[1]]

# Unscale training results

high_trains <- train_perf[,1] * scale_parameters$`scaled:scale`[1] +
                    scale_parameters$`scaled:center`[1];high_trains
 
high_train_actuals <- train[,1] * scale_parameters$`scaled:scale`[1] +
                    scale_parameters$`scaled:center`[1];high_train_actuals

low_trains <- train_perf[,2] * scale_parameters$`scaled:scale`[2] +
                    scale_parameters$`scaled:center`[2];low_trains

low_train_actuals <- train[,2] * scale_parameters$`scaled:scale`[2] +
                    scale_parameters$`scaled:center`[2];low_train_actuals

train_day=seq(1:nrow(train))

train_results <- data.frame(cbind(high_trains, high_train_actuals,
                                  low_trains,low_train_actuals, 
                                  train_day));train_results

# Training performance

cat('Training Error: ', forecast$result.matrix[1,])

head(train_results)

ggplot() + geom_line(data=train_results, aes(x=train_results[,5], y=train_results[,4] , colour='Actual Price')) +
  geom_line(data=train_results, aes(x=train_results[,5], y=train_results[,3], colour='Low Price Prediction')) +
  labs(x='Day', y='Share Price ($)') +
  ggtitle('Low Price Prediction: Training Performance') + 
  theme(legend.position = c(0.775,0.2), legend.justification = c(0, 1)) +
  scale_color_manual(name=NULL, values = c('red','seagreen3')) +
  theme(plot.title = element_text(hjust = 0.5))
  ggsave('cw4_train_low.pdf')
  
ggplot() + geom_line(data=train_results, aes(x=train_results[,5], y=train_results[,2] , colour='Actual Price')) +
  geom_line(data=train_results, aes(x=train_results[,5], y=train_results[,1], colour='High Price Prediction')) +
  labs(x='Day', y='Share Price ($)') +
  ggtitle('High Price Prediction: Training Performance') + 
  theme(legend.position = c(0.775,0.2), legend.justification = c(0, 1)) +
  scale_color_manual(name=NULL, values = c('red','seagreen3')) +
  theme(plot.title = element_text(hjust = 0.5))
  ggsave('cw4_train_high.pdf')

# Testing 
  
preds <- predict(forecast, test);preds

# Unscaling predictions and actuals

high_predictions <- preds[, 1] * scale_parameters$`scaled:scale`[1] +
                    scale_parameters$`scaled:center`[1];high_predictions

low_predictions <- preds[, 2] * scale_parameters$`scaled:scale`[2] +
                   scale_parameters$`scaled:center`[2];low_predictions

high_actuals <- test[, 1] * scale_parameters$`scaled:scale`[1] +
                scale_parameters$`scaled:center`[1];high_actuals

low_actuals <- test[, 2] * scale_parameters$`scaled:scale`[2] +
               scale_parameters$`scaled:center`[2];low_actuals

ema_actuals <- test[, 15] * scale_parameters$`scaled:scale`[15] +
               scale_parameters$`scaled:center`[15];ema_actuals

sma_actuals <- test[, 17] * scale_parameters$`scaled:scale`[17] +
               scale_parameters$`scaled:center`[17];sma_actuals

sma_hi_actuals <- test[, 18] * scale_parameters$`scaled:scale`[18] +
  scale_parameters$`scaled:center`[18];sma_hi_actuals

test_day=seq(1:nrow(test))

# Testing results dataframe 

results <- data.frame(cbind(high_predictions, high_actuals,
                            low_predictions, low_actuals, 
                            ema_actuals, test_day, sma_actuals, sma_hi_actuals));results

# High and low price errors

cat('High predictions error: \n', rmse(results[,2], results[,1]))
cat('Low predictions error: \n', rmse(results[,4], results[,3]))

# Decisions for buy/sell/hold

capital = 10000
stocks_owned = 0
purchase_price = 0
var = 0.01
upper = 1 + var
lower = 1 - var
expMove <- (na.omit(tail(EM10,-split*length(EM10))));expMove
buys = 0
sells = 0
decisions <- c()

for(i in 1:nrow(results)){
  
  predictHigh = results[i, 1]
  actualHigh = results[i, 2]
  predictLow = results[i, 3]
  actualLow = results[i, 4]
  ema = results[i, 5]
  
  entry_price = upper * predictLow
  exit_price = lower * predictHigh
  
  if(between(actualLow, lower * predictLow, upper * predictLow) && (entry_price < ema) && (capital != 0) && (i < nrow(results))){
    stocks_owned <- capital / entry_price
    purchase_price <- entry_price
    capital = 0
    buys <- buys + 1
    decisions[i] <- 1
    cat('Day:', i, 'Buy' ,stocks_owned, 'shares at: $', entry_price, '\n')
  }
  
  else if ((between(actualHigh, lower * predictHigh, upper * predictHigh) && (capital == 0) &&
            (exit_price > purchase_price))){
    capital = stocks_owned * exit_price
    stocks_owned = 0 
    sells <- sells + 1
    decisions[i] <- -1
    cat('Day:', i, 'Sold at: $', exit_price, ' Balance: $', capital, '\n')
  }
  
  else {
    decisions[i] <- 0
    cat('Day:',i,'Hold\n')}

  if(i==nrow(results)){
    if(capital==0){
      capital = stocks_owned * CL[503,1]
      stocks_owned = 0
      sells <- sells + 1
      decisions[i] <- 0
      cat('Day:', i, 'Sold at: $', exit_price, ' Balance: $', capital, '\n')
    }
    profit = capital - 10000
    trades = buys + sells
    cat('$',profit, 'profit after ',trades, 'trades: ', buys, 'buys and', sells, 'sells.\n')
  }
}

# Plotting performance over unseen period

ggplot() + geom_line(data=results, aes(x=results[,6], y=results[,4] , colour='Actual Price')) +
  geom_line(data=results, aes(x=results[,6], y=results[,5], colour='10-Day EMA')) +
  geom_line(data=results, aes(x=results[,6], y=results[,3], colour='Low Price Prediction')) +
  labs(x='Day', y='Share Price ($)') +
  ggtitle('Low Price Prediction: Testing Performance') + 
  theme(legend.position = c(0.8,1), legend.justification = c(0, 1)) +
  scale_color_manual(name=NULL, values = c('deepskyblue','seagreen3', 'lightcoral')) +
  theme(plot.title = element_text(hjust = 0.5))
  ggsave('cw4_test_low.pdf')

ggplot() + geom_line(data=results, aes(x=results[,6], y=results[,2] , colour='Actual Price')) +
  geom_line(data=results, aes(x=results[,6], y=results[,1], colour='High Price Prediction')) +
  labs(x='Day', y='Share Price ($)') +
  ggtitle('High Price Prediction: Testing Performance') + 
  theme(legend.position = c(0.8,1), legend.justification = c(0, 1)) +
  scale_color_manual(name=NULL, values = c('seagreen3','lightcoral')) +
  theme(plot.title = element_text(hjust = 0.5))
  ggsave('cw4_test_high.pdf')

# Plotting decisions taken 
  
cat(decisions)

dec <- data.frame(decisions);dec
decisions_made <- data.frame(cbind(dec, results[,6]));decisions_made
colnames(decisions_made) <- c('Decison', 'Day')

ggplot() + geom_line(data=decisions_made, aes(x=decisions_made[,2], y=decisions_made[,1]), col='seagreen3')+
  labs(x='Day', y='Decision') +
  ggtitle('Trading Activity') + 
  theme(plot.title = element_text(hjust = 0.5)) +
  theme(axis.title.y = element_blank()) +
  scale_y_continuous(breaks=c(-1.0,0,1.0), labels=c('Sell', 'Hold', 'Buy'))
  ggsave('cw4_trading_activity.pdf')
  
# Comparison - Mean

capital = 10000
stocks_owned = 0
purchase_price = 0
var = 0.01
upper = 1 + var
lower = 1 - var
buys = 0
sells = 0
comp_decisions <- c()

for(i in 1:nrow(results)){
  
  actualHigh = results[i, 2]
  actualLow = results[i, 4]
  sma_lo = results[i, 7]
  sma_hi = results[i, 8]
  
  entry_price = upper * sma_lo
  exit_price = lower * sma_hi
  
  if(between(actualLow, lower * sma, upper * sma_lo) && (capital != 0) && (i < nrow(results))){
    stocks_owned <- capital / entry_price
    purchase_price <- entry_price
    capital = 0
    buys <- buys + 1
    comp_decisions[i] <- 1
    cat('Day:', i, 'Buy' ,stocks_owned, 'shares at: $', entry_price, '\n')
  }
  
  else if ((between(actualHigh, lower * sma_hi, upper * sma_hi) && (capital == 0) &&
            (exit_price > purchase_price))){
    capital = stocks_owned * exit_price
    stocks_owned = 0 
    sells <- sells + 1
    comp_decisions[i] <- -1
    cat('Day:', i, 'Sold at: $', exit_price, ' Balance: $', capital, '\n')
  }
  
  else {
    comp_decisions[i] <- 0
    cat('Day:',i,'Hold\n')}
  
  if(i==nrow(results)){
    if(capital==0){
      capital = stocks_owned * CL[503,1]
      stocks_owned = 0
      sells <- sells + 1
      comp_decisions[i] <- -1
      cat('Day:', i, 'Sold at: $', exit_price, ' Balance: $', capital, '\n')
    }
    profit = capital - 10000
    trades = buys + sells
    cat('$',profit, 'profit after ',trades, 'trades: ', buys, 'buys and', sells, 'sells.\n')
  }
}

cat(comp_decisions)

# Plotting comparison method

ggplot() + geom_line(data=results, aes(x=results[,6], y=results[,4] , colour='Low Price')) +
  geom_line(data=results, aes(x=results[,6], y=results[,7], colour='SMA Low Prediction')) +
  labs(x='Day', y='Share Price ($)') +
  ggtitle('Low Price SMA Prediction Performance') + 
  theme(legend.position = c(0.8,1), legend.justification = c(0, 1)) +
  scale_color_manual(name=NULL, values = c('deepskyblue', 'lightcoral')) +
  theme(plot.title = element_text(hjust = 0.5))
  ggsave('cw4_comparison_low.pdf')

ggplot() + geom_line(data=results, aes(x=results[,6], y=results[,2] , colour='High Price')) +
  geom_line(data=results, aes(x=results[,6], y=results[,8], colour='SMA High Prediction')) +
  labs(x='Day', y='Share Price ($)') +
  ggtitle('High Price SMA Prediction Performance') + 
  theme(legend.position = c(0.8,1), legend.justification = c(0, 1)) +
  scale_color_manual(name=NULL, values = c('deepskyblue', 'lightcoral')) +
  theme(plot.title = element_text(hjust = 0.5))
  ggsave('cw4_comparison_high.pdf')

d <- data.frame(comp_decisions);d
comp_decisions_made <- data.frame(cbind(d, results[,6]));decisions_made
colnames(decisions_made) <- c('Decison', 'Day')

ggplot() + geom_line(data=comp_decisions_made, aes(x=comp_decisions_made[,2], y=comp_decisions_made[,1]), col='seagreen3')+
  labs(x='Day', y='Decision') +
  ggtitle('SMA-Method Trading Activity') + 
  theme(plot.title = element_text(hjust = 0.5)) +
  theme(axis.title.y = element_blank()) +
  scale_y_continuous(breaks=c(-1.0,0,1.0), labels=c('Sell', 'Hold', 'Buy'))
  ggsave('cw4_comparison_activity.pdf')
