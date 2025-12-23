#!/usr/bin/env python3

import sqlite3
import json
import sys

def debug_cache():
    db_path = "api/users.db"
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    print("🔍 Auto Analysis Cache Debug")
    print("=" * 50)
    
    # 모든 캐시 항목 확인
    cursor.execute('''
        SELECT analysis_time, symbol, query_length, target_length, top_k, results
        FROM auto_analysis_cache 
        ORDER BY analysis_time DESC 
        LIMIT 5
    ''')
    
    results = cursor.fetchall()
    
    if not results:
        print("❌ No cache entries found!")
        return
    
    for i, (analysis_time, symbol, query_length, target_length, top_k, results_json) in enumerate(results):
        print(f"\n📊 Cache Entry #{i+1}")
        print(f"   Time: {analysis_time}")
        print(f"   Symbol: {symbol}")
        print(f"   Query: {query_length}")
        print(f"   Target: {target_length}")
        print(f"   Top K: {top_k}")
        print(f"   Results JSON Length: {len(results_json) if results_json else 0}")
        
        # JSON 파싱 시도
        try:
            parsed_data = json.loads(results_json) if results_json else None
            if parsed_data:
                print(f"   ✅ JSON parsing: OK")
                
                # 구조 분석
                if 'query_pattern' in parsed_data:
                    qp = parsed_data['query_pattern']
                    print(f"   🎯 Query Pattern: {type(qp)}")
                    if qp and 'candles' in qp:
                        candles = qp['candles']
                        print(f"      Candles: {type(candles)} (length: {len(candles) if candles else 'N/A'})")
                    else:
                        print(f"      ❌ Query pattern candles missing or None")
                
                if 'similar_patterns' in parsed_data:
                    sp = parsed_data['similar_patterns']
                    print(f"   📈 Similar Patterns: {type(sp)} (length: {len(sp) if sp else 'N/A'})")
                    
                    if sp and len(sp) > 0:
                        first_pattern = sp[0]
                        print(f"      First Pattern Type: {type(first_pattern)}")
                        if isinstance(first_pattern, dict) and 'candles' in first_pattern:
                            first_candles = first_pattern['candles']
                            print(f"      First Pattern Candles: {type(first_candles)} (length: {len(first_candles) if first_candles else 'N/A'})")
                            
                            # 🔍 각 캔들의 type 속성 확인
                            if first_candles and len(first_candles) > 0:
                                print(f"      🔍 Candle types analysis:")
                                for idx, candle in enumerate(first_candles):
                                    if isinstance(candle, dict):
                                        candle_type = candle.get('type', '없음')
                                        print(f"         Candle {idx}: type='{candle_type}', keys={list(candle.keys())}")
                                    else:
                                        print(f"         Candle {idx}: Not a dict! Type: {type(candle)}")
                                        
                                # 타입별 필터링 테스트
                                pattern_candles = [c for c in first_candles if isinstance(c, dict) and c.get('type') == 'pattern']
                                forecast_candles = [c for c in first_candles if isinstance(c, dict) and c.get('type') == 'forecast']
                                no_type_candles = [c for c in first_candles if isinstance(c, dict) and 'type' not in c]
                                
                                print(f"         📊 Pattern candles: {len(pattern_candles)}")
                                print(f"         📊 Forecast candles: {len(forecast_candles)}")
                                print(f"         📊 No-type candles: {len(no_type_candles)}")
                        else:
                            print(f"      ❌ First pattern candles missing")
                else:
                    print(f"   ❌ Similar patterns missing")
            else:
                print(f"   ❌ Parsed data is None or empty")
                
        except json.JSONDecodeError as e:
            print(f"   ❌ JSON parsing error: {e}")
        except Exception as e:
            print(f"   ❌ Unexpected error: {e}")
    
    conn.close()

if __name__ == "__main__":
    debug_cache()