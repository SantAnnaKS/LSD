/******************************************************************************

	ISLAND LSD MODEL (BASIC)
	------------------------

	Written by Marcelo C. Pereira, University of Campinas

	Copyright Marcelo C. Pereira
	Distributed under the GNU General Public License

	This is the single code file for the model in LSD.

 ******************************************************************************/

#define NO_POINTER_INIT							// disable pointer checking

#include "fun_head_fast.h"

// agent-type codes
#define EXPLORER 3
#define IMITATOR 2
#define MINER 1

// macro to encode island coordinates into a single island ID number
#define ISLAND_ID( X, Y ) ( ( X + LAST_T ) * 1e6 + ( Y + LAST_T ) )

// support C++ function (code at the end of the file)
void add_island( object *sea, int x, int y, double & count );// add new island

MODELBEGIN

///////////////////////////// SEA object equations /////////////////////////////

//////////////////
EQUATION( "Init" )
/*
Technical variable to create the sea lattice and initialize
it with the islands and agents.
It is computed only once in the beginning of the simulation.
Must be the first variable in the list.
*/

USE_ZERO_INSTANCE;								// enable zero-instance objects

v[0] = v[1] = 0;								// island/known island counters
v[2] = V( "pi" );								// island probability
v[3] = V( "l0" );								// initial number of known islands
v[4] = V( "l0radius" );							// rsearch radius for initial islands

// make sure there is an island at (0, 0)
add_island( THIS, 0, 0, v[0] );

// create random islands to fill the initial radius plus one
for ( i = - v[4] - 1; i <= v[4] + 1; ++i )
	for ( j = - v[4] - 1; j <= v[4] + 1; ++j )
		// draw the existence of an island (except in (0, 0))
		if ( RND < v[2] && ! ( i == 0 && j == 0 ) )
			// create island and add to the graphical lattice if required
			add_island( THIS, i, j, v[0] );

// set the KnownIsland object instances to be nodes of a network
INIT_NET( "KnownIsland", "DISCONNECTED", 1 );

// draw the required number of known islands ((0, 0) is always known)
while( v[1] < v[3] )
{
	if ( v[1] == 0 )
		cur = SEARCH( "Island" );				// first island at (0, 0) or (1, 1)
	else
		cur = RNDDRAW_FAIR( "Island" );			// drawn existing island

	i = VS( cur, "_xIsland" );					// island (0, 0)-centered coords.
	j = VS( cur, "_yIsland" );

	// avoid the islands just over the radius or already set as known
	if ( VS( cur, "_known" ) || ( i < - v[4] || i > v[4] || j < - v[4] || j > v[4] ) )
		continue;

	if ( v[1] == 0 )							// first known island?
		cur1 = SEARCH( "KnownIsland" );			// pick existing object
	else
		cur1 = ADDOBJL( "KnownIsland", 0 );		// add new object instance

	WRITE_SHOOKS( cur, cur1 );					// save pointer to KnownIsland object
	WRITE_SHOOKS( cur1, cur );					// save pointer to Island object

	++v[1];										// count the known islands
	WRITES( cur, "_known", 1 );					// flag island as known
	DELETE( SEARCHS( cur1, "Miner" ) );			// remove empty miner instance
	VS( cur1, "_Init" );						// initialize the known island
}

WRITE( "J", v[0] );								// number of existing islands in t=1
WRITE( "northFrontier", v[4] + 1 );				// register the initial sea borders
WRITE( "southFrontier", - v[4] - 1 );
WRITE( "eastFrontier", v[4] + 1 );
WRITE( "westFrontier", - v[4] - 1 );

// create agents objects
j = V( "N" );									// the total number of agents
INIT_TSEARCH( "KnownIsland" );					// prepare turbo search

for ( i = 0; i < j; ++i )
{
	k = uniform_int( 1, v[1] );					// island where the agent starts
	cur = TSEARCH( "KnownIsland", k );			// pointer to KnownIsland object
	cur2 = ADDOBJLS( cur, "Miner", 0 );			// add new miner object instance

	if ( i == 0 )								// first agent?
		cur1 = SEARCH( "Agent" );				// pick existing agent object
	else
		cur1 = ADDOBJL( "Agent", 0 );			// add new agent object instance

	WRITE_SHOOKS( cur1, cur2 );					// save pointer to agent as miner
	WRITE_SHOOKS( cur2, cur1 );					// save pointer to Agent object
	cur3 = SHOOKS( cur );						// pointer to island

	WRITES( cur1, "_idAgent", i + 1 );			// save agent id number
	WRITES( cur1, "_xAgent", VS( cur3, "_xIsland" ) );// agent x coordinate
	WRITES( cur1, "_yAgent", VS( cur3, "_yIsland" ) );// agent y coordinate
	WRITELS( cur1, "_a", MINER, -1 );			// agent initial state (miner)
}

PARAMETER;										// just do it once

RESULT( 1 )

//////////////////
EQUATION( "Step" )
/*
Technical variable to force the calculation of any Variable
that has to be calculated early in the time step.
Must be the second variable in the list, after 'Init'.
*/

CYCLE( cur, "Agent" )							// make sure agents decisions are
	VS( cur, "_a" );							// taken first during time step

RESULT( 1 )

///////////////
EQUATION( "g" )
// Total output (GDP) growth rate.

v[1] = VL( "Q", 1 );							// past period GDP
v[2] = V( "Q" );								// current GDP

if ( v[1] <= 0 || v[2] <= 0 )
	END_EQUATION( 0 );							// don't compute if Q is zero

RESULT( log( v[2] ) - log( v[1] ) )

///////////////
EQUATION( "e" )
// Number of explorer agents on the sea.
RESULT( COUNT_CND( "Agent", "_a", "==", EXPLORER ) )

///////////////
EQUATION( "i" )
// Number of imitator agents on the sea.
RESULT( COUNT_CND( "Agent", "_a", "==", IMITATOR ) )

///////////////
EQUATION( "m" )
// Number of agents currently mining on all islands.
RESULT( SUM( "_m" ) )

///////////////
EQUATION( "Q" )
// Total output (GDP).
RESULT( SUM( "_Qisland" ) )

///////////////
EQUATION( "J" )
/*
The number of existing islands.
Expands the size of the sea as agents get closer to the borders.
*/

v[0] = CURRENT;									// number of islands
v[1] = V( "pi" );								// island probability
v[2] = V( "westFrontier" );						// existing sea frontiers
v[3] = V( "eastFrontier" );
v[4] = V( "southFrontier" );
v[5] = V( "northFrontier" );

// check agents closer to the existing sea frontier islands
v[6] = MIN( "_xAgent" );
v[7] = MAX( "_xAgent" );
v[8] = MIN( "_yAgent" );
v[9] = MAX( "_yAgent" );

// expand to the west if required
if ( v[6] <= v[2] )
{
	WRITE( "westFrontier", --v[2] );			// update the frontier
	for ( i = v[2], j = v[4]; j <= v[5]; ++j )	// move south -> north
		if ( RND < v[1] )						// is it an island?
			add_island( THIS, i, j, v[0] );
}

// expand to the east if required
if ( v[7] >= v[3] )
{
	WRITE( "eastFrontier", ++v[3] );			// update the frontier
	for ( i = v[7], j = v[4]; j <= v[5]; ++j )	// move south -> north
		if ( RND < v[1] )						// is it an island?
			add_island( THIS, i, j, v[0] );
}

// expand to the south if required
if ( v[8] <= v[4] )
{
	WRITE( "southFrontier", --v[4] );			// update the frontier
	for ( j = v[4], i = v[2]; i <= v[3]; ++i )	// move west -> east
		if ( RND < v[1] )						// is it an island?
			add_island( THIS, i, j, v[0] );
}

// expand to the north if required
if ( v[9] >= v[5] )
{
	WRITE( "northFrontier", ++v[5] );			// update the frontier
	for ( j = v[5], i = v[2]; i <= v[3]; ++i )	// move west -> east
		if ( RND < v[1] )						// is it an island?
			add_island( THIS, i, j, v[0] );
}

RESULT( v[0] )


///////////////////////// KNOWNISLAND object equations /////////////////////////

///////////////////
EQUATION( "_Init" )
// Initializes new known island and builds the diffusion (star) network

v[1] = V( "rho" );								// locality degree of interaction
v[2] = V( "minSgnPrb" );						// minimum signal probability

i = VS( SHOOK, "_xIsland" );					// island coordinates
j = VS( SHOOK, "_yIsland" );

WRITE( "_s", abs( i ) + abs( j ) );				// island initial prod. coeff.
WRITE( "_idKnown", INCRS( PARENT, "l", 1 ) - 1 );// save known island id

// run over all known islands to create network links
CYCLES( PARENT, cur, "KnownIsland" )
	// check if the link already exists (no link to self)
	if ( cur != THIS && SEARCH_LINK( V_NODEIDS( cur ) ) == NULL )
	{	// coordinates of the current network spoke (existing known island)
		k = VS( SHOOKS( cur ), "_xIsland" );
		h = VS( SHOOKS( cur ), "_yIsland" );

		// calculate the maximum signal probability (intensity)
		v[0] = exp( - v[1] * ( abs( i - k ) + abs( j - h ) ) );

		// only create link if probability is above minimum threshold
		if ( v[0] > v[2] )
		{
			ADDLINKW( cur, v[0] );				// add bidirectional link
			ADDLINKWS( cur, THIS, v[0] );		// weighted by signal probability
		}
	}

RESULT( T )

EQUATION_DUMMY( "l", "" )
// Number of known islands (technologies).

////////////////
EQUATION( "_m" )
// Number of agents currently mining on island.

RESULT( COUNT( "Miner" ) )


//////////////////////
EQUATION( "_Qisland" )
// Total output of island.
RESULT( SUM( "_Qminer" ) )

////////////////
EQUATION( "_c" )
// The productivity of the island.

v[1] = V( "_m" );

if ( v[1] == 0 )
	END_EQUATION( 0 );							// avoid division by zero

RESULT( V( "_Qisland" ) / v[1] )


//////////////////////////// MINER object equations ////////////////////////////

/////////////////////
EQUATION( "_Qminer" )
// Output of miner.
RESULT( V( "_s" ) * pow( V( "_m" ), V( "alpha" ) - 1 ) )


//////////////////////////// AGENT object equations ////////////////////////////

////////////////
EQUATION( "_a" )
// The agent state.

i = V( "_xAgent" );								// agent coordinates in t-1
j = V( "_yAgent" );

// if explorer or imitator, move in the lattice sea
if ( CURRENT != MINER )
{
	// if it is an explorer, move randomly across the sea
	if ( CURRENT == EXPLORER )
	{
		h = uniform_int( 1, 4 );				// decide direction to move
		switch( h )
		{
			case 1:								// north
				++j;
				break;
			case 2:								// south
				--j;
				break;
			case 3:								// east
				++i;
				break;
			case 4:								// west
				--i;
		}

		// check if island exists
		cur = SEARCH_CNDS( PARENT, "_idIsland", ISLAND_ID( i, j ) );
	}

	// if it is an imitator, move straight to the new island
	if ( CURRENT == IMITATOR )
	{
		h = V( "_xTarget" );					// target imitated island
		k = V( "_yTarget" );

		if ( abs( h - i ) > abs( k - j ) )		// distance on x larger?
			i += copysign( 1, h - i );			// get closer by the x direction
		else
			j += copysign( 1, k - j );			// get closer by the y direction

		if ( i == h && j == k )
			cur = SEARCH_CNDS( PARENT, "_idIsland", ISLAND_ID( i, j ) );
		else
			cur = NULL;
	}

	WRITE( "_xAgent", i );						// update agent position
	WRITE( "_yAgent", j );

	if ( cur != NULL )							// found an island?
	{
		if ( ! VS( cur, "_known" ) )			// discovered a new island?
		{
			cur1 = ADDOBJLS( PARENT, "KnownIsland", 0 );// add new instance
			cur2 = SEARCHS( cur1, "Miner" );	// pointer to the empty Miner

			WRITE_SHOOKS( cur, cur1 );			// save pointer to KnownIsland obj.
			WRITE_SHOOKS( cur1, cur );			// save pointer to Island object

			WRITES( cur, "_known", 1 );			// flag island as known
			VS( cur1, "_Init" );				// initialize the known island

			// compute the productivity coefficient of the discovered island
			// uniform( -sqrt( 3 ), sqrt( 3 ) ) is a r.v. with mean 0 and var. 1
			v[1] = ( 1 + poisson( V( "lambda" ) ) ) *
				   ( abs( i ) + abs( j ) + V( "phi" ) * V( "_Qlast" ) +
				   	 uniform( -sqrt( 3 ), sqrt( 3 ) ) );

			WRITES( cur1, "_s", v[1] );			// update island prod. coefficient
		}
		else
		{
			cur1 = SHOOKS( cur );				// known island, just pick pointer
			cur2 = ADDOBJLS( cur1, "Miner", 0 );// add new miner object instance
		}

		WRITE_SHOOK( cur2 );					// save pointer to agent as miner
		WRITE_SHOOKS( cur2, THIS );				// save pointer to Agent object

		WRITES( cur2, "_agentId", V( "_idAgent" ) );// keep pairing between Agent
		WRITE( "_knownId", VS( cur1, "_idKnown" ) );// and KnownIsland while mining

		END_EQUATION( MINER );					// becomes a miner again
	}
}

// a miner decides if become explorer
if ( CURRENT == MINER && RND < V( "epsilon" ) )
{
	V( "_leave" );								// leave current island
	END_EQUATION( EXPLORER );					// become explorer
}

// an explorer or miner evaluates becoming an imitator
// explorer considers just the possibility of listening the best overall island
// miner considers best listened island only if better than current one
if ( ( CURRENT == EXPLORER && RND < V( "_wBest" ) ) ||
	 ( CURRENT == MINER && V( "_cTarget" ) > VLS( PARENTS( SHOOK ), "_c", 1 ) ) )
{
	if ( CURRENT == EXPLORER )
	{
		WRITE( "_xTarget", V( "_xBest" ) );		// target to best overall island
		WRITE( "_yTarget", V( "_yBest" ) );
	}
	else
		V( "_leave" );							// miner leave current island

	END_EQUATION( IMITATOR );					// become imitator
}

RESULT( CURRENT )								// keep type

EQUATION_DUMMY( "_xAgent", "_a" )
// The x coordinate of the agent.

EQUATION_DUMMY( "_yAgent", "_a" )
// The y coordinate of the agent.

//////////////////////
EQUATION( "_cTarget" )
// The productivity of island with the best received (listened) signal.

if ( SHOOK == NULL )							// not connected to a miner obj.?
	END_EQUATION( CURRENT );					// keep current values

v[1] = VL( "m", 1 );							// total number of miners

v[2] = v[3] = v[4] = 0;							// best prod./str. over./listened
i = j = h = k = 0;								// best island coord. over./list.

if ( v[1] != 0 )								// avoid zero division
	// check all network connections of current island for signals
	CYCLE_LINKS( PARENTS( SHOOK ), curl )
	{
		cur = LINKTO( curl );					// object connected

		// the probability of message being received from this connection
		v[5] = ( VLS( cur, "_m", 1 ) / v[1] ) * V_LINK( curl );
		v[6] = VLS( cur, "_c", 1 );				// connection productivity

		if ( v[6] > v[2] )						// is it the best overall so far?
		{
			v[2] = v[6];						// save best overall productivity
			v[3] = v[5];						// its signal strength
			i = VS( SHOOKS( cur ), "_xIsland" );// and the island coordinates
			j = VS( SHOOKS( cur ), "_yIsland" );
		}

		if ( RND < v[5] && v[6] > v[4]  )		// best signal received/listened?
		{
			v[4] = v[6];						// save best listened productivity
			h = VS( SHOOKS( cur ), "_xIsland" );// and the island coordinates
			k = VS( SHOOKS( cur ), "_yIsland" );
		}
	}

WRITE( "_wBest", v[3] );						// best overall island signal str.
WRITE( "_xBest", i );							// best overall island coordinates
WRITE( "_yBest", j );							// the one to be used as explorer

WRITE( "_xTarget", h );							// best listened island coordinates
WRITE( "_yTarget", k );							// the one to be imitated as miner

RESULT( v[4] )

EQUATION_DUMMY( "_wBest", "_cTarget" )
// The signal strength of the best overall island.

EQUATION_DUMMY( "_xBest", "_cTarget" )
// The x coordinate of the best overall island.

EQUATION_DUMMY( "_yBest", "_cTarget" )
// The y coordinate of the best overall island.

EQUATION_DUMMY( "_xTarget", "_cTarget" )
// The x coordinate of island with the best received (listened) signal.

EQUATION_DUMMY( "_yTarget", "_cTarget" )
// The y coordinate of island with the best received (listened) signal.

////////////////////
EQUATION( "_leave" )
// Function to prepare miner to leave current island.

WRITE( "_Qlast", VLS( SHOOK, "_Qminer", 1 ) );	// save last output
WRITE( "_knownId", 0 );							// disconnect Agent->KnownIsland
DELETE( SHOOK );								// delete associated Miner object
WRITE_SHOOK( NULL );							// disconnect Agent from Miner

RESULT( T )

EQUATION_DUMMY( "_Qlast", "" )
// Last agent output as a miner.

MODELEND

// support C++ functions

//// add one (unknown) island to the model
void add_island( object *sea, int x, int y, double & count )
{
	object *island;

	if ( count == 0 )							// first island?
		island = SEARCHS( sea, "Island" );		// pick existing object
	else
		island = ADDOBJLS( sea, "Island", 0 );	// add new object instance

	++count;									// update the islands counter
	WRITES( island, "_idIsland", ISLAND_ID( x, y ) );// save island id (coords.)
	WRITES( island, "_xIsland", x );			// save island x coordinate
	WRITES( island, "_yIsland", y );			// save island y coordinate
}

//// close simulation special commands
void close_sim( void ) { }
