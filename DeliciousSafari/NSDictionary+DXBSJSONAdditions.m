//
//  BSJSONAdditions
//
//  Created by Blake Seely on 2/1/06.
//  Copyright 2006 Blake Seely - http://www.blakeseely.com  All rights reserved.
//  Permission to use this code:
//
//  Feel free to use this code in your software, either as-is or 
//  in a modified form. Either way, please include a credit in 
//  your software's "About" box or similar, mentioning at least 
//  my name (Blake Seely).
//
//  Permission to redistribute this code:
//
//  You can redistribute this code, as long as you keep these 
//  comments. You can also redistribute modified versions of the 
//  code, as long as you add comments to say that you've made 
//  modifications (keeping these original comments too).
//
//  If you do use or redistribute this code, an email would be 
//  appreciated, just to let me know that people are finding my 
//  code useful. You can reach me at blakeseely@mac.com

#import "NSDictionary+DXBSJSONAdditions.h"
#import "NSScanner+DXBSJSONAdditions.h"

NSString *dxJsonIndentString = @"\t"; // Modify this string to change how the output formats.
const int dxJsonDoNotIndent = -1;

@implementation NSDictionary (DXBSJSONAdditions)

+ (NSDictionary *)dictionaryWithDXJSONString:(NSString *)jsonString
{
	NSScanner *scanner = [[NSScanner alloc] initWithString:jsonString];
	NSDictionary *dictionary = nil;
	[scanner dxScanJSONObject:&dictionary];
	[scanner release];
	return dictionary;
}

- (NSString *)dxJsonStringValue
{
    return [self dxJsonStringValueWithIndentLevel:0];
}

@end

@implementation NSDictionary (PrivateDXBSJSONAdditions)

- (NSString *)dxJsonStringValueWithIndentLevel:(int)level
{
	NSMutableString *jsonString = [[NSMutableString alloc] init];
    [jsonString appendString:dxJsonObjectStartString];
	
	NSEnumerator *keyEnum = [self keyEnumerator];
	NSString *keyString = [keyEnum nextObject];
	NSString *valueString;
	if (keyString != nil) {
		valueString = [self dxJsonStringForValue:[self objectForKey:keyString] withIndentLevel:level];
        if (level != dxJsonDoNotIndent) { // indent before each key
            [jsonString appendString:[self dxJsonIndentStringForLevel:level]];
        }            
		[jsonString appendFormat:@" %@ %@ %@", [self dxJsonStringForString:keyString], dxJsonKeyValueSeparatorString, valueString];
	}
	
	while (keyString = [keyEnum nextObject]) {
		valueString = [self dxJsonStringForValue:[self objectForKey:keyString] withIndentLevel:level]; // TODO bail if valueString is nil? How to bail successfully from here?
        [jsonString appendString:dxJsonValueSeparatorString];
        if (level != dxJsonDoNotIndent) { // indent before each key
            [jsonString appendFormat:@"%@", [self dxJsonIndentStringForLevel:level]];
        }
		[jsonString appendFormat:@" %@ %@ %@", [self dxJsonStringForString:keyString], dxJsonKeyValueSeparatorString, valueString];
	}
	
	//[jsonString appendString:@"\n"];
	[jsonString appendString:dxJsonObjectEndString];
	
	return [jsonString autorelease];
}

- (NSString *)dxJsonStringForValue:(id)value withIndentLevel:(int)level
{	
	NSString *jsonString;
	if ([value respondsToSelector:@selector(characterAtIndex:)]) // String
		jsonString = [self dxJsonStringForString:(NSString *)value];
	else if ([value respondsToSelector:@selector(keyEnumerator)]) // Dictionary
		jsonString = [(NSDictionary *)value dxJsonStringValueWithIndentLevel:(level + 1)];
	else if ([value respondsToSelector:@selector(objectAtIndex:)]) // Array
		jsonString = [self dxJsonStringForArray:(NSArray *)value withIndentLevel:level];
	else if (value == [NSNull null]) // null
		jsonString = dxJsonNullString;
	else if ([value respondsToSelector:@selector(objCType)]) { // NSNumber - representing true, false, and any form of numeric
		NSNumber *number = (NSNumber *)value;
		if (((*[number objCType]) == 'c') && ([number boolValue] == YES)) // true
			jsonString = dxJsonTrueString;
		else if (((*[number objCType]) == 'c') && ([number boolValue] == NO)) // false
			jsonString = dxJsonFalseString;
		else // attempt to handle as a decimal number - int, fractional, exponential
			// TODO: values converted from exponential json to dict and back to json do not format as exponential again
			jsonString = [[NSDecimalNumber decimalNumberWithDecimal:[number decimalValue]] stringValue];
	} else {
		// TODO: error condition - it's not any of the types that I know about.
		return nil;
	}
	
	return jsonString;
}

- (NSString *)dxJsonStringForArray:(NSArray *)array withIndentLevel:(int)level
{
	NSMutableString *jsonString = [[NSMutableString alloc] init];
	[jsonString appendString:dxJsonArrayStartString];
	
	if ([array count] > 0) {
		[jsonString appendString:[self dxJsonStringForValue:[array objectAtIndex:0] withIndentLevel:level]];
	}
	
	unsigned int i;
	for (i = 1; i < [array count]; i++) {
		[jsonString appendFormat:@"%@ %@", dxJsonValueSeparatorString, [self dxJsonStringForValue:[array objectAtIndex:i] withIndentLevel:level]];
	}
	
	[jsonString appendString:dxJsonArrayEndString];
	return [jsonString autorelease];
}

- (NSString *)dxJsonStringForString:(NSString *)string
{
	NSMutableString *jsonString = [[NSMutableString alloc] init];
	[jsonString appendString:dxJsonStringDelimiterString];

	// Build the result one character at a time, inserting escaped characters as necessary
	unsigned int i;
	unichar nextChar;
	for (i = 0; i < [string length]; i++) {
		nextChar = [string characterAtIndex:i];
		switch (nextChar) {
		case '\"':
			[jsonString appendString:@"\\\""];
			break;
		case '\\':
			[jsonString appendString:@"\\n"];
			break;
		/* TODO: email out to json group on this - spec says to handlt his, examples and example code don't handle this.
		case '\/':
			[jsonString appendString:@"\\/"];
			break;
		*/ 
		case '\b':
			[jsonString appendString:@"\\b"];
			break;
		case '\f':
			[jsonString appendString:@"\\f"];
			break;
		case '\n':
			[jsonString appendString:@"\\n"];
			break;
		case '\r':
			[jsonString appendString:@"\\r"];
			break;
		case '\t':
			[jsonString appendString:@"\\t"];
			break;
		/* TODO: Find and encode unicode characters here?
		case '\u':
			[jsonString appendString:@"\\n"];
			break;
		*/
		default:
			[jsonString appendString:[NSString stringWithCharacters:&nextChar length:1]];
			break;
		}
	}
	[jsonString appendString:dxJsonStringDelimiterString];
	return [jsonString autorelease];
}

- (NSString *)dxJsonIndentStringForLevel:(int)level
{
    NSMutableString *indentString = [[NSMutableString alloc] init];
    if (level != dxJsonDoNotIndent) {
        [indentString appendString:@"\n"];
        int i;
        for (i = 0; i < level; i++) {
            [indentString appendString:dxJsonIndentString];
        }
    }
    
    return [indentString autorelease];
}

@end
