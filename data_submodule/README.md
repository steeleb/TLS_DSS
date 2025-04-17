# TLS_DSS/data_submodule

The data submodule of the TLS DSS stores and integrates data used in the model 
and knowledge engine subsystems.

## Inflow Balance

The decision for pump operation is made within the context of natural inflow. 
There are two pumping regimes currently used by the pump operators during the
regulatory period of July 1 until September 11: 220 cfs regime (“consistent”) 
and a 220/440 regime (“staggered”). The 220 cfs regime aims to have a consistent
daily average of 220 cfs (or more, as natural flow allows) transported through 
the Alva B Adams tunnel. The consistent regime is first attempted to be met by 
natural flow (inflow to Grand/SMR) and then supplemented by pumping operations
from Granby reservoir via the Farr pump. If additional water is available 
through natural inflow, that water is diverted into the Adams tunnel. The 
staggered regime pump 220 during weekends and 550 during weekdays resulting in
an average 440 CFS per week. Generally speaking, if Front Range demand is met 
by natural flow, the pumping system is not engaged for the entirety of the 
regulatory period.

The inflow_balance.R script preps the inflow/water balance data and pulls 
additional data whenever the {targets} workflow is triggered.

![Flow Conceptual Model. Conceptual diagram of Shadow Mountain Reservoir and 
Grand Lake inflow/outflow and monitoring locations. Green arrows are inflows 
(North Inlet and East Inlet into Grand Lake and the Colorado River North Fork 
into Shadow Mountain). Red arrows indicate outflows (Adams Tunnel to the Front 
Range from Grand Lake and Colorado River outlet from Shadow Mountain. Blue 
square is the interflow between Shadow Mountain and Grand Lake “Chipmunk Lane”)
and the blue triangle is the location of the Shadow Mountain buoy used for 
neural network development.](images/flow_concept.jpg)
