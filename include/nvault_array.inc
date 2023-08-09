
/*	
	nVault Array
	    v0.2
	  by bugsy
*/

/* Change log
	v0.1
	- Initial release as a stand-alone include. These functions were initially included as part of 
	  nvault utility but I decided to break them apart since these functions aren't quite utility 
	  functions, they are an extension of nVault base functionality to save/load data.
	- Added nvault_isarray() and nvault_arraysize().
	
	v0.2
	- Added checking while loading the array data in nvault_read_array() to make sure the data  
	  is nvault_set_array() data. If the data is not array data, the plugin will fail. If the scripter 
	  sees this error in logs, then he is attempting to read regular text data as an array which 
	  should not be attempted. There is also the nvault_isarray() function that can be used to 
	  check the data, but this shouldn't be necessary if the plugin was written properly.
*/

#if defined _nvault_array_included
	#endinput
#endif
#define _nvault_array_included

#if !defined _nvault_included
	#include <nvault>
#endif

//********************************************************************************************
//   Increase this value if your plugin throws the below error:
//   "Array size too large, you must increase NVAULT_ARRAY_MAXARRAYSIZE in nvault_array.inc"   

const _NVAULT_ARRAY_MAXARRAYSIZE = 500;
//********************************************************************************************

const _NVAULT_ARRAY_CELLSIZE = 5;
const _NVAULT_ARRAY_BUFFERSIZE = ( ( _NVAULT_ARRAY_MAXARRAYSIZE * _NVAULT_ARRAY_CELLSIZE ) + 1 );
const _NVAULT_ARRAY_BYTEMAP = 0b11110000;
const _NVAULT_ARRAY_NULLBYTE = 0b10101010;

/* Description: Set array data in a vault

   Param(s):
   vault - Vault file handle ID that was returned by nvault_open(). Do not pass an nvault utility file ID.
   key[] - Key for data to store.
   array[] - Array of data to store.
   size - Size of array to store (use sizeof(array)).
   
   Return value: 1 on success, 0 on failure.
	
   Comments: None.
*/
stock nvault_set_array( vault , const key[] , const any:array[] , size )
{
	new iArrayPos , iOutputPos , iValue[ 1 ] , szString[ _NVAULT_ARRAY_BUFFERSIZE ];
	
	if ( size > _NVAULT_ARRAY_MAXARRAYSIZE )
		set_fail_state( "[nVault Array] Array size too large, you must increase NVAULT_ARRAY_MAXARRAYSIZE in nvault_array.inc." );
	
	while ( ( iArrayPos < size ) && ( iOutputPos < charsmax( szString ) ) )
	{
		iValue[ 0 ] = array[ iArrayPos++ ];
		
		if ( !( cellmin <= iValue[ 0 ] <= cellmax ) )
			set_fail_state( "[nVault Array] Value exceeds valid long value range." );

		szString[ iOutputPos++ ] = _nvault_array_byte_map( iValue );

		for ( new i = 0 ; i < 4 ; i++ )
			szString[ iOutputPos++ ] = !iValue{ i } ? _NVAULT_ARRAY_NULLBYTE : iValue{ i };
	}
	
	szString[ iOutputPos ] = EOS;
	
	return nvault_set( vault , key , szString );
}

/* Description: Get array data in a vault

   Param(s):
   vault - Vault file handle ID that was returned by nvault_open(). Do not pass an nvault utility file ID.
   key[] - Key for record to retrieve
   array[] - Array to store retrieved data in.
   size - Size of array that data is being retrieved in.
   timestamp - Timestamp of record (passed by reference)
   
   Return value: The number of array elements that were stored in the nvault array record.
	
   Comments: Do not read an nvault record as an array when it was not stored with nvault_set_array()..
*/
stock nvault_get_array( vault , const key[] , any:array[] , size , &timestamp=0 )
{
	new iStringPos , iArrayPos , iValue[ 1 ] , bmByteMap , szString[ _NVAULT_ARRAY_BUFFERSIZE ];
	
	if ( size > _NVAULT_ARRAY_MAXARRAYSIZE )
		set_fail_state( "[nVault Array] Array size too large, you must increase _NVAULT_ARRAY_MAXARRAYSIZE in nvault_array.inc." );
	
	//Read data from nvault. Switched from nvault_get() to nvault_lookup() to allow timestamp retrieval.
	if ( nvault_lookup( vault , key , szString , charsmax( szString ) , timestamp ) )
	{
		//Each individual nvault array value consumes 5 characters. If the length of the string mod 5 is not 0 then
		//the data is not array data.
		if ( strlen( szString ) % 5 )
			set_fail_state( "[nVault Array] Can only use nvault_get_array() on data that was saved using nvault_set_array()." );
		
		//Loop through the string, making sure the index of the array and string is within boundaries.
		while ( szString[ iStringPos ] && ( iStringPos < charsmax( szString ) ) && ( iArrayPos < size ) )
		{
			//Every 5th character of the string is a byte-map which holds a boolean in bits 1-4 for whether or not
			//the following 4 characters are null. Bits 5-8 are set to constant 1 so these bits can be checked at each 
			//iteration to make sure they exist. If they do not, then the data is not nvault array data.
			//[1111 0000] : 1's are always 1, 0's are booleans for whether or not adjacent bytes are null.
			if ( ( ( bmByteMap = szString[ iStringPos++ ] ) & _NVAULT_ARRAY_BYTEMAP ) != _NVAULT_ARRAY_BYTEMAP )
				set_fail_state( "[nVault Array] Can only use nvault_get_array() on data that was saved using nvault_set_array()." );
				
			//Load byte value in cell. If the byte map says it is null, set it to null (0), otherwise set it so the 
			//value stored in the byte. 
			for ( new i = 0 ; i < 4 ; i++ )
			{
				iValue{ i } = bmByteMap & ( 1 << i ) ? szString[ iStringPos ] : 0;
				iStringPos++;
			}
		
			//Assign value to array.
			array[ iArrayPos++ ] = iValue[ 0 ];
		}
	}
	
	return iArrayPos;
}

/* Description: Check if an nvault entry is an array

   Param(s):
   vault - Vault file handle ID that was returned by nvault_open(). Do not pass an nvault utility file ID.
   key[] - Key for record to check
   
   Return value: true / false
*/
stock bool:nvault_isarray( vault , const key[] )
{
	new szData[ _NVAULT_ARRAY_BUFFERSIZE ] , iTS , iDataLen , bool:bRetVal;
	
	if ( nvault_lookup( vault , key , szData , charsmax( szData ) , iTS ) && ( iDataLen = strlen( szData ) ) )
	{
		bRetVal = true;
			
		for ( new i = 0 ; i < iDataLen ; i += _NVAULT_ARRAY_CELLSIZE )
		{
			if ( ( szData[ i ] & _NVAULT_ARRAY_BYTEMAP ) != _NVAULT_ARRAY_BYTEMAP )
			{
				bRetVal = false;
				break;
			}
		}
	}
	
	return bRetVal;
}

/* Description: Get the size of an nvault array

   Param(s):
   vault - Vault file handle ID that was returned by nvault_open(). Do not pass an nvault utility file ID.
   key[] - Key for record to check
   
   Return value:  0 = Record does not exist or is not an nvault array record
		 >0 = How large the array is (in cells)
*/
stock nvault_arraysize( vault , const key[] )
{
	new szData[ _NVAULT_ARRAY_BUFFERSIZE ] , iTS , iDataLen , bool:bIsArray , iRetVal;
	
	if ( nvault_lookup( vault , key , szData , charsmax( szData ) , iTS ) && ( iDataLen = strlen( szData ) ) )
	{
		if ( ( iDataLen < charsmax( szData ) ) && !( iRetVal % _NVAULT_ARRAY_CELLSIZE ) )
		{
			bIsArray = true;
			
			for ( new i = 0 ; i < iDataLen ; i += _NVAULT_ARRAY_CELLSIZE )
			{
				if ( ( szData[ i ] & _NVAULT_ARRAY_BYTEMAP ) != _NVAULT_ARRAY_BYTEMAP )
				{
					bIsArray = false;
					break;
				}
			}
			
			if ( bIsArray == true )
			{
				iRetVal = ( iDataLen / _NVAULT_ARRAY_CELLSIZE );
			}
		}
	}
	
	return iRetVal;
}

stock _nvault_array_byte_map( iValue[ 1 ] )
{
	new iOut[ 1 ] = { _NVAULT_ARRAY_BYTEMAP };

	for ( new i = 0 ; i < 4 ; i++)
		iOut[ 0 ] |= !iValue{ i } ? 0 : ( 1 << i );

	return iOut[ 0 ];
}
