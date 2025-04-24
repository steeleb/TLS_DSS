# Three Lakes System Decision Support System

Three Lakes System decision support system (TLS DSS) repository for forecasting water 
temperature in Shadow Mountain Reservoir using forecasted weather and varying 
operational pumping regimes.

The code in this repository is covered by the MIT use license. We request that 
all downstream uses of this work be available to the public when possible.

Repository contact: B Steele (b dot steele at colostate dot edu)

## Background

Water temperature is an indicator of water quality, as it governs much of the 
biological activity in freshwater systems. Northern Water, the municipal 
subdistrict that delivers drinking water to approximately 1 million people in 
northern Colorado and irrigation water for ~600,000 acres of land, has had 
recurring issues with water clarity in Grand Lake, the deepest natural lake in 
Colorado. They believe that the clarity issues in Grand Lake are primarily due 
to algal and diatom growth in Shadow Mountain reservoir which are pushed into 
Grand when they initiate pumping operations. Clarity in Grand is regulated by 
Senate Document 80 which dates back to 1937 and the inception of the Colorado 
Big-Thompson project, however in 2016 stakeholders and operators adopted a 
system of “goal qualifiers” for Grand. The goal qualifiers are defined through 
Secchi disc depth measurements (a measure of water clarity), requiring a 
3.8-meter Secchi depth average and 2.5-meter Secchi depth daily minimum to 
be met throughout the July 1 to September 11 regulatory season.

Water in the Three Lakes System (TLS) naturally flows from Grand into Shadow Mountain 
into Granby, but pumping operations reverse that natural order by introducing 
hypolimnetic water (cold water) from Granby reservoir into Shadow Mountain.
This process reverses natural flow from Shadow Mountain into Grand and finally 
into the Alva B Adams tunnel to serve the Front Range (Figure 1). Northern 
suspects there is a biological “sweet spot” for water temperature in Shadow 
Mountain Reservoir that may reduce algal and diatom growth and therefore 
mitigate clarity impacts during pumping operations. The optimal temperature 
for reducing algal growth is to keep the upper 1m of water less than 15°C in 
the Summer and Fall and to reduce diatom growth is to keep the average 
temperature of 0-5m (“integrated depth”) greater than 14°C in the Spring and 
early Summer, which is a bit of a “Goldilocks” problem. Currently, Northern 
Water uses simulations of a computationally-intensive physical model to estimate 
clarity in Grand Lake; however these models take days to run and it is not 
possible to continually run them to create daily estimates, much less forecasts 
of either water temperature or clarity. 

![Figure 1](https://github.com/user-attachments/assets/1a22f221-96bb-4ed5-8911-25c08b40f501)

*Figure 1. Cartoon schematic of the three lakes system*

We have created an auto-regressive neural network to predict water temperature 
at the two depth horizons (near surface 0.5m and integrated depth 0-5m) that 
incorporates the parameters of the physical model that Northern Water uses. 
This model is accurate and performs better than a persistence model 
(yesterday-is-today) and can make an estimate of temperature at the two depth 
horizons in seconds. The value of this model (and the decision support system) 
is the speed at which these estimates and forecasts can be made as well as the
accuracy. The usefulness of a decision support system is not just for this 
estimate of tomorrow’s temperature, but the ability to use forecasted 
meteorological and pump operations to estimate lake temperature days into the
future. This decision support system would allow for Northern Water and their
partners to test augmented pumping operations to determine the impacts to water
temperature (and therefore clarity, if the Goldilocks temperature hypothesis is
true), since we already know that the model is sensitive to large changes in 
pumping operations. Currently, pumping operations are mostly defined by expert
operators, meaning that operators have embedded knowledge of the system. The
hope is that between their expert knowledge and this data driven model, we can
provide additional context to the decisions these operators are making on daily 
basis.

## DSS Submodules

![Submodules](https://github.com/user-attachments/assets/a3318e7e-8146-4ca9-9e86-8f0da268058b)

*Figure 2. Sketch of decision support submodules for the TLS DSS*

## DSS Dialog Sketch

![DSS Dialog](https://github.com/user-attachments/assets/f8439a9d-76f7-438f-ae06-492d987514c4)

*Figure 3. Sketch of the TLS DSS dialog user interface*

## Repository Function

This repository is built using {targets} infrastructure. To run the workflow 
and update the underlying data, use the command `targets::tar_make()` in the R
console. 

## Shiny App

This repository includes code to deploy a shiny app. The app can be accessed 
[here](https://b-steele.shinyapps.io/dss_shiny/).
