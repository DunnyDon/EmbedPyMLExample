system"l /app/kxdemo/kxinstall/delta-data/ANZ_HDB";
system"l p.q";
np:.p.import`numpy;
sk:.p.import`sklearn;
/train test split method taken from Kx github
traintestsplit:{[x;y;sz]`xtrain`ytrain`xtest`ytest!raze(x;y)@\:/:(0,floor n*1-sz)_neg[n]?n:count x};

/----------------DATA PREPROCESSING-----------------------
/create ohlc table with an extra column nextClose
ohlc: reverse 1_update nextClose:prev close from reverse select qty:avg qty,open:first price,high:max price,low:min price,close:last price by 1 xbar transactTime.minute from Trade where date=max date,sym=`ANZ;
bOrders:select bqty:avg qty,bhigh:max price,bavg:avg price by 1 xbar transactTime.minute  from Order where date=max date,sym=`ANZ,orderStatus=`new,side="B";
sOrders:select sqty:avg qty,shigh:max price,savg:avg price by 1 xbar transactTime.minute  from Order where date=max date,sym=`ANZ,orderStatus=`new,side="S";
ohlc:(ij/)(ohlc;bOrders;sOrders);
/Split data in features and predictions
/We will attempt to predict this new column nextClose
/ytrain are the features that we will use in our testing phase
/xtrain is the rest of the data
/[xy]test is used as a validation to see how well the algorithm performs
features:flip value flip delete nextClose from 0!ohlc;
closeVals:exec nextClose from ohlc;
/use kx function to split data into training and testing
data:traintestsplit[features;closeVals;0.3];


/---------------ML training and prediction-----------------
/import and define algortihm
lr:.p.import[`sklearn.linear_model;`:LinearRegression];
lrr:lr[`normalize pykw"True"];
/fit the algo to your training data and use the testing data to make predictions
learner:lrr[`:fit]. data`xtrain`ytrain;
predicts:learner[`:predict;data`xtest];
show predicts`;
/show data`ytest;
/-------------Python Equivalent---------------------------
/from sklearn.linear_model import LinearRegression
/llr=LinearRegression(normalize=True)
/lrr.fit(xtrain,ytrain)
/predicts=lrr.predict(data`xtest)

/-------------Results analysis-------------------------------
/create table of results and look at the comparisons between actual and predicted values to see how well we did
results:update diff: predictions-actual,movementPrediction:(signum deltas[first actual;actual])=signum deltas[first predictions;predictions] from `time xasc flip `time`actual`predictions!((data`xtest)[;0];data`ytest;predicts`);
/We will score the accuracy of the algorithm on whether or not it scores the movement of the stock 
show select accuracy:(count i)%count results from results where movementPrediction;
/now lets try predict the next price based on the data we have
/create mini table of data which now includes our new predicted price
newPredict:([]time:1#desc (data`xtest)[;0]+1;prediction: learner[`:predict;-1#features]`);
/show "New Predictions";
/show newPredict;
/-----------Results Visualization---------------------------

/create image which displays our actual data results Vs what our algortihm predicted  
.qp.go[500;500]
    .qp.stack (
        .qp.line[results; `time; `actual]
            .qp.s.geom[`size`fill`alpha!(2; .gg.colour.SteelBlue; 0xaf)]
            ,.qp.s.legend["Legend"; `Actual`Predicted`newVal!.gg.colour`SteelBlue`FireBrick`DarkSeaGreen];        
        .qp.line[results; `time; `predictions]
            .qp.s.geom[`size`fill`alpha!(2; .gg.colour.FireBrick; 0xaf)];
        .qp.point[newPredict;`time;`prediction]
            .qp.s.geom[`size`fill`alpha!(2; .gg.colour.DarkSeaGreen; 0xaf)]
        );
