{-------------------------------------------------------------------------------

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.

-------------------------------------------------------------------------------}
{===============================================================================

  List sorters

    Classes designed to sort lists by using only list indices.

    The list must provide compare and exchange functions, both accepting two
    indices, and also lowest and highest item index.

    Sorter then uses provided compare function to compare two items and, when
    necessary, exchanges these two items using provided exchange function.

    The compare function should return positive value when first item is
    larger (should be higher) than second item, zero when the two items are
    equal and negative value when first item is smaller (is in correct order
    in relation to the second item).

    Following sorting algorithms are currently implemented:

      - bubble sort
      - quick sort (could use some testing and optimizations)
      - bogo sort (only for fun and tests)

  Version 1.1.1 (2020-03-09)

  Last change 2020-08-02

  ©2018-2020 František Milt

  Contacts:
    František Milt: frantisek.milt@gmail.com

  Support:
    If you find this code useful, please consider supporting its author(s) by
    making a small donation using the following link(s):

      https://www.paypal.me/FMilt

  Changelog:
    For detailed changelog and history please refer to this git repository:

      github.com/TheLazyTomcat/Lib.ListSorters

  Dependencies:
    AuxTypes   - github.com/TheLazyTomcat/Lib.AuxTypes
    AuxClasses - github.com/TheLazyTomcat/Lib.AuxClasses

===============================================================================}
unit ListSorters;

{$IFDEF FPC}
  {$MODE ObjFPC}
{$ENDIF}
{$H+}

interface

uses
  AuxClasses;

{===============================================================================
--------------------------------------------------------------------------------
                                  TListSorter
--------------------------------------------------------------------------------
===============================================================================}

type
  TCompareMethod = Function(Index1,Index2: Integer): Integer of object;
  TCompareFunction = Function(Context: Pointer; Index1,Index2: Integer): Integer;

  TExchangeMethod = procedure(Index1,Index2: Integer) of object;
  TExchangeFunction = procedure(Context: Pointer; Index1,Index2: Integer);

  TBreakEvent = procedure(Sender: TObject; var Break: Boolean) of object;
  TBreakCallback = procedure(Context: Pointer; Sender: TObject; var Break: Boolean);

{===============================================================================
    TListSorter - class declaration
===============================================================================}
  TListSorter = class(TCustomObject)
  protected
    fReversed:          Boolean;
    fStabilized:        Boolean;
    fContext:           Pointer;
    fLowIndex:          Integer;
    fHighIndex:         Integer;
    fReversedCompare:   Boolean;
    fCompareMethod:     TCompareMethod;
    fCompareFunction:   TCompareFunction;
    fExchangeMethod:    TExchangeMethod;
    fExchangeFunction:  TExchangeFunction;
    fCompareCoef:       Integer;
    fOnBreakEvent:      TBreakEvent;
    fOnBreakCallback:   TBreakCallback;
    // some statistics
    fCompareCount:      Integer;
    fExchangeCount:     Integer;
    // sorting stabilization
    fIndexArray:        array of Integer;
    Function CompareItems(Index1,Index2: Integer): Integer; virtual;
    procedure ExchangeItems(Index1,Index2: Integer); virtual;
    procedure InitCompareCoef; virtual;
    procedure InitStatistics; virtual;
    procedure Execute; virtual; abstract; // must be implemented by descendants
  public
    constructor Create; overload;
    constructor Create(CompareMethod: TCompareMethod; ExchangeMethod: TExchangeMethod); overload;
    constructor Create(Context: Pointer; CompareFunction: TCompareFunction; ExchangeFunction: TExchangeFunction); overload;
    destructor Destroy; override;
    procedure Initialize(CompareMethod: TCompareMethod; ExchangeMethod: TExchangeMethod); overload; virtual;
    procedure Initialize(Context: Pointer; CompareFunction: TCompareFunction; ExchangeFunction: TExchangeFunction); overload; virtual;
    Function Sorted(LowIndex, HighIndex: Integer): Boolean; overload; virtual;
    Function Sorted: Boolean; overload; virtual;
    procedure Sort(LowIndex, HighIndex: Integer); overload; virtual;
    procedure Sort; overload; virtual;
    property Reversed: Boolean read fReversed write fReversed;
    property Stabilized: Boolean read fStabilized write fStabilized;
    property Context: Pointer read fContext write fContext;
    property LowIndex: Integer read fLowIndex write fLowIndex;
    property HighIndex: Integer read fHighIndex write fHighIndex;
    property ReversedCompare: Boolean read fReversedCompare write fReversedCompare;
    property CompareMethod: TCompareMethod read fCompareMethod write fCompareMethod;
    property CompareFunction: TCompareFunction read fCompareFunction write fCompareFunction;
    property ExchangeMethod: TExchangeMethod read fExchangeMethod write fExchangeMethod;
    property ExchangeFunction: TExchangeFunction read fExchangeFunction write fExchangeFunction;
    property CompareCount: Integer read fCompareCount;
    property ExchangeCount: Integer read fExchangeCount;
    property OnBreak: TBreakEvent read fOnBreakEvent write fOnBreakEvent;
    property OnBreakEvent: TBreakEvent read fOnBreakEvent write fOnBreakEvent;
    property OnBreakCallback: TBreakCallback read fOnBreakCallback write fOnBreakCallback;
  end;

{===============================================================================
--------------------------------------------------------------------------------
                               TListBubbleSorter
--------------------------------------------------------------------------------
===============================================================================} 
{===============================================================================
    TListBubbleSorter - class declaration
===============================================================================}

  TListBubbleSorter = class(TListSorter)
  protected
    procedure Execute; override;
  end;

{===============================================================================
--------------------------------------------------------------------------------
                                TListQuickSorter
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    TListQuickSorter - class declaration
===============================================================================}

  TListQuickSorter = class(TListSorter)
  protected
    procedure Execute; override;
  end;

{===============================================================================
--------------------------------------------------------------------------------
                                TListBogoSorter
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    TListBogoSorter - class declaration
===============================================================================}

  // only for fun, do not use, seriously...
  TListBogoSorter = class(TListSorter)
  protected
    procedure Execute; override;
  end;

implementation

uses
  SysUtils;

type
  ELSBreakException = class(Exception); // internal silent exception

{===============================================================================
--------------------------------------------------------------------------------
                                  TListSorter
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    TListSorter - class implementation
===============================================================================}
{-------------------------------------------------------------------------------
    TListSorter - protected methods
-------------------------------------------------------------------------------}

Function TListSorter.CompareItems(Index1,Index2: Integer): Integer;
var
  BreakProcessing:  Boolean;
begin
If Index1 <> Index2 then
  begin
    BreakProcessing := False;
    If Assigned(fOnBreakEvent) then
      fOnBreakEvent(Self,BreakProcessing)
    else If Assigned(fOnBreakCallback) then
      fOnBreakCallback(fContext,Self,BreakProcessing);
    If not BreakProcessing then
      begin
        If Assigned(fCompareMethod) then
          Result := fCompareMethod(Index1,Index2) * fCompareCoef
        else If Assigned(fCompareFunction) then
          Result := fCompareFunction(fContext,Index1,Index2) * fCompareCoef
        else
          Result := 0;
        Inc(fCompareCount);
        // stabilization
        If (Result = 0) and (Length(fIndexArray) > 0) then
          Result := (fIndexArray[Index1 - fLowIndex] - fIndexArray[Index2 - fLowIndex]);
      end
    else raise ELSBreakException.Create('Processing aborted.');
    If fReversed then
      Result := -Result;    
  end
else Result := 0;
end;

//------------------------------------------------------------------------------

procedure TListSorter.ExchangeItems(Index1,Index2: Integer);
var
  TempIdx:  Integer;
begin
If Index1 <> Index2 then
  begin
    If Assigned(fExchangeMethod) then
      fExchangeMethod(Index1,Index2)
    else If Assigned(fExchangeFunction) then
      fExchangeFunction(fContext,Index1,Index2);
    Inc(fExchangeCount);      
    // stabilization
    If Length(fIndexArray) > 0 then
      begin
        TempIdx := fIndexArray[Index1 - fLowIndex];
        fIndexArray[Index1 - fLowIndex] := fIndexArray[Index2 - fLowIndex];
        fIndexArray[Index2 - fLowIndex] := TempIdx;
      end;
  end;
end;

//------------------------------------------------------------------------------

procedure TListSorter.InitCompareCoef;
begin
If fReversedCompare then
  fCompareCoef := -1
else
  fCompareCoef := 1;
end;

//------------------------------------------------------------------------------

procedure TListSorter.InitStatistics;
begin
fCompareCount := 0;
fExchangeCount := 0;
end;

{-------------------------------------------------------------------------------
    TListSorter - public methods
-------------------------------------------------------------------------------}

constructor TListSorter.Create;
begin
inherited Create;
fReversed := False;
fStabilized := False;
fContext := nil;
fLowIndex := 0;
fHighIndex := -1;
fCompareMethod := nil;
fCompareFunction := nil;
fExchangeMethod := nil;
fExchangeFunction := nil;
fCompareCoef := 1;
fOnBreakEvent := nil;
fOnBreakCallback := nil;
InitStatistics;
SetLength(fIndexArray,0);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

constructor TListSorter.Create(CompareMethod: TCompareMethod; ExchangeMethod: TExchangeMethod);
begin
Create;
Initialize(CompareMethod,ExchangeMethod);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

constructor TListSorter.Create(Context: Pointer; CompareFunction: TCompareFunction; ExchangeFunction: TExchangeFunction);
begin
Create;
Initialize(Context,CompareFunction,ExchangeFunction);
end;

//------------------------------------------------------------------------------

destructor TListSorter.Destroy;
begin
SetLength(fIndexArray,0);
inherited;
end;

//------------------------------------------------------------------------------

procedure TListSorter.Initialize(CompareMethod: TCompareMethod; ExchangeMethod: TExchangeMethod);
begin
fCompareMethod := CompareMethod;
fExchangeMethod := ExchangeMethod;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure TListSorter.Initialize(Context: Pointer; CompareFunction: TCompareFunction; ExchangeFunction: TExchangeFunction);
begin
fContext := Context;
fCompareFunction := CompareFunction;
fExchangeFunction := ExchangeFunction;
end;

//------------------------------------------------------------------------------

Function TListSorter.Sorted(LowIndex, HighIndex: Integer): Boolean;
begin
fLowIndex := LowIndex;
fHighIndex := HighIndex;
Result := Self.Sorted;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TListSorter.Sorted: Boolean;
var
  i:  Integer;
begin
Result := True;
InitCompareCoef;
try
  For i := fLowIndex to Pred(fHighIndex) do
    If CompareItems(i,i + 1) > 0 then
      begin
        Result := False;
        Break{For i};
      end;
except
  on E: ELSBreakException do
    // drop the exception
  else
    raise;
end;
end;

//------------------------------------------------------------------------------

procedure TListSorter.Sort(LowIndex, HighIndex: Integer);
begin
fLowIndex := LowIndex;
fHighIndex := HighIndex;
Sort;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure TListSorter.Sort;
var
  i:  Integer;
begin
InitCompareCoef;
InitStatistics;
If fHighIndex > fLowIndex then
  begin
    If fStabilized then
      begin
        // initialize index array for stabilization
        SetLength(fIndexArray,fHighIndex - fLowIndex + 1);
        For i := Low(fIndexArray) to High(fIndexArray) do
          fIndexArray[i] := i;
      end
    else SetLength(fIndexArray,0);  // to be sure
    try
      try
        Execute;
      except
        on E: ELSBreakException do
          // drop the exception
        else
          raise;
      end;
    finally
      SetLength(fIndexArray,0); // clear the array after use
    end;
  end;
end;


{===============================================================================
--------------------------------------------------------------------------------
                               TListBubbleSorter
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    TListBubbleSorter - class implementation
===============================================================================}
{-------------------------------------------------------------------------------
    TListBubbleSorter - protected methods
-------------------------------------------------------------------------------}

procedure TListBubbleSorter.Execute;
var
  i,j:      Integer;
  ExchCntr: Integer;
begin
For i := fHighIndex downto fLowIndex do
  begin
    ExchCntr := 0;
    For j := fLowIndex to Pred(i) do
      If CompareItems(j,j + 1) > 0 then
        begin
          ExchangeItems(j,j + 1);
          Inc(ExchCntr);
        end;
    If ExchCntr <= 0 then
      Break{For i};
  end;
end;


{===============================================================================
--------------------------------------------------------------------------------
                                TListQuickSorter
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    TListQuickSorter - class implementation
===============================================================================}
{-------------------------------------------------------------------------------
    TListQuickSorter - protected methods
-------------------------------------------------------------------------------}

procedure TListQuickSorter.Execute;

  procedure QuickSort(Left,Right: Integer);
  var
    PivotIdx,LowIdx,HighIdx: Integer;
  begin
    repeat
      LowIdx := Left;
      HighIdx := Right;
      PivotIdx := (Left + Right) shr 1;
      repeat
        while CompareItems(PivotIdx,LowIdx) > 0 do
          Inc(LowIdx);
        while CompareItems(PivotIdx,HighIdx) < 0 do
          Dec(HighIdx);
        If LowIdx <= HighIdx then
          begin
            ExchangeItems(LowIdx,HighIdx);
            If PivotIdx = LowIdx then
              PivotIdx := HighIdx
            else If PivotIdx = HighIdx then
              PivotIdx := LowIdx;
            Inc(LowIdx);
            Dec(HighIdx);  
          end;
      until LowIdx > HighIdx;
      If Left < HighIdx then
        QuickSort(Left,HighIdx);
      Left := LowIdx;
    until LowIdx >= Right;
  end;

begin
QuickSort(fLowIndex,fHighIndex);
end;


{===============================================================================
--------------------------------------------------------------------------------
                                TListBogoSorter
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    TListBogoSorter - class implementation
===============================================================================}
{-------------------------------------------------------------------------------
    TListBogoSorter - protected methods
-------------------------------------------------------------------------------}

procedure TListBogoSorter.Execute;
var
  i:  Integer;
begin
Randomize;
while not Sorted do
  For i := fLowIndex to Pred(fHighIndex) do
    If Random(2) <> 0 then
      ExchangeItems(i,i + 1);
end;

end.
