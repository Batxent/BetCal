//: A UIKit based Playground for presenting user interface
  
import UIKit

//MARK: Math

extension Int {

    //阶乘
    //3.factorial() = 3 * 2 * 1
    func factorial() -> Int {
        guard self > 0 else { return 0 }
        return (1...self).reduce(1, { $0 * $1 })
    }

    //阶乘和
    //3.factorialSum() == 3! + 2! + 1!
    func factorialSum() -> Int {
        guard self > 0  else { return 0 }
        return (1...self).reduce(0, { $0 + $1.factorial() })
    }
}

//组合概率
//c(n,m) = n!/((n-m)!*m!), m should less than n
func c(_ n: Int, _ m: Int) -> Int {
    guard n <= m  else { return 0 }
    return n.factorial() / (m.factorial() * ( n - m ).factorial())
}

extension Array where Element: Hashable {
    //幂集
    var powerSet: [[Element]] {
        guard !isEmpty else { return [[]] }
        return Array(self[1...]).powerSet.flatMap { [$0, [self[0]] + $0] }
    }

    func combinations(choose count: Int) -> [[Element]] {
        guard !self.isEmpty else { return [] }
        guard self.count >= count else { return [] }

        return self.powerSet.compactMap { (subSet) -> [Element]? in
            if subSet.count == count {
                return subSet
            }else {
                return nil
            }
        }
    }

}


//MARK: DataModel

struct Team: Hashable {
    let name: String
}

struct Match: Hashable, Comparable {

    var home: Team?
    var away: Team?

    var odds: Double = 0
    var win: Bool = false

    var homeScore: Int?
    var awayScore: Int?

    init(home: Team?, away: Team?, odds: Double, win: Bool) {
        self.home = home
        self.away = away
        self.odds = odds
        self.win = win

        self.homeScore = 0
        self.awayScore = 0
    }

    static func == (lhs: Match, rhs: Match) -> Bool {
        return lhs.odds == rhs.odds
    }

    static func > (lhs: Match, rhs: Match) -> Bool {
        return lhs.odds > rhs.odds
    }

    static func < (lhs: Match, rhs: Match) -> Bool {
        return lhs.odds < rhs.odds
    }
}

struct Bet: Hashable {
    let matches: [Match]
    let amount: Int

    //输赢
    var win: Bool {
        let loseMatches = matches.filter { (match) -> Bool in
            return !match.win
        }
        return (loseMatches.count <= 0)
    }

    var netWin: Double {
        if self.win {
            return Double(self.amount) * self.odds
        }else {
            return 0
        }
    }

    var odds: Double {
        var _odds: Double = 1
        for match in self.matches {
            _odds *= match.odds
        }
        return _odds
    }

}


//MARK: Engine

typealias Ongoing = ((Match) -> Match)

func win(_ match: Match) -> Match {
    var m = match;
    m.win = true
    return m
}

func lose(_ match: Match) -> Match {
    var m = match;
    m.win = false
    return m
}

func bestOdds(matches: [Match], of count: Int) -> [Match]? {
    return sort(matches: matches, of: count) { (m0, m1) -> Bool in
        m0.odds > m1.odds
    }
}

func worstOdds(matches: [Match], of count: Int) -> [Match]? {
    return sort(matches: matches, of: count) { (m0, m1) -> Bool in
        m0.odds < m1.odds
    }
}

private func sort(matches: [Match], of count: Int, by: ((Match, Match) -> Bool)) -> [Match]? {
    guard matches.count > count else { return nil }
    guard matches.count == count else { return matches }

    let sorted = matches.sorted(by: by)
    return Array(sorted[..<count])
}


/// - Parameters:
///   - count:
///   - singleBet:
/// - Returns: (amount，netwin)
@discardableResult
func calNetwin(_ matches: [Match], choose count: Int, singleBet: Int, _ ongoing: Ongoing?) -> (Double, Double) {

    var finalMatches = matches
    if let going = ongoing {
        finalMatches = matches.map { (_match) -> Match in
            going(_match)
        }
    }

    var finalCount = count
    if count == 1 {
        finalCount = matches.count
    }

    let bets = finalMatches.combinations(choose: finalCount).map { (_matches) -> Bet in
        Bet(matches: _matches, amount: singleBet)
    }

    let sumAmount = Double(bets.count * singleBet);
    let netwin = bets.reduce(0) { (sum, bet) -> Double in
        sum + bet.netWin
        } - sumAmount

    return (sumAmount, netwin)
}

func head(matches: [Match], of count: Int) -> ((Match) -> Match) {
    let sub = matches[..<count]
    return { match in
        if sub.contains(match) {
            return lose(match)
        }else {
            return win(match)
        }
    }
}

///   - lose: 若为nil,则输出多个收益期望值，从全胜到输光投注额
private func calNetwin(_ matches: [Match], choose: Int, singleBet: Int, lose: Int?) {

    let upcaseMatches = matches.sorted { $0.odds > $1.odds }
    let lowcaseMatches = matches.sorted { $0.odds < $1.odds }

    if let _loseCount = lose {

        // netwin at least
        let low = calNetwin(upcaseMatches, choose: choose, singleBet: singleBet, head(matches: upcaseMatches, of: _loseCount))

        // netwin at best
        let high = calNetwin(lowcaseMatches, choose: choose, singleBet: singleBet, head(matches: lowcaseMatches, of: _loseCount))

        print("\(matches.count)串\(choose) 总投注额：\(low.0) | 输\(_loseCount)场，收益区间：[\(low.1) --- \(high.1)]")

    }else {

        for x in 0..<(matches.count - choose + 2) {
            calNetwin(matches, choose: choose, singleBet: singleBet, lose: x)
        }
    }
}

extension Array: BetSummary where Element == Double {

    private func oddsToMatch(_ odds: Double) -> Match {
        return Match(home: Team(name: ""), away: Team(name: ""), odds: odds, win: true)
    }

    @discardableResult
    func summary(choose: Int, singleBet: Int) -> String {
        var resultString = ""
        for x in 0..<(self.count - choose + 2) {
            let printString = self.summary(choose: choose, singleBet: singleBet, lose: x)
            resultString.append(contentsOf: "\n\(printString)")
        }
        return resultString
    }

    @discardableResult
    private func summary(choose: Int, singleBet: Int, lose: Int) -> String {

        let upcaseMatches = self.sorted(by: >).map(oddsToMatch)
        let lowcaseMatches = self.sorted(by: <).map(oddsToMatch)

        let low = calNetwin(upcaseMatches, choose: choose, singleBet: singleBet, head(matches: upcaseMatches, of: lose))

        let high = calNetwin(lowcaseMatches, choose: choose, singleBet: singleBet, head(matches: lowcaseMatches, of: lose))

        let printString = "\(self.count)串\(choose) 总投注额：\(low.0) | 输\(lose)场，收益区间：[\(low.1) --- \(high.1)]"
        print(printString)
        return printString
    }
}

extension Array where Element == Match {

    private func matchToOdds(_ match: Match) -> Double {
        return match.odds
    }

    func summary(choose: Int, singleBet: Int) -> String {
        return self.map(matchToOdds).summary(choose: choose, singleBet: singleBet)
    }

    private func summary(choose: Int, singleBet: Int, lose: Int) -> String {
        return self.map(matchToOdds).summary(choose: choose, singleBet: singleBet, lose: lose)
    }

}

extension Double {

    var win: Match {
        return Match(home: nil, away: nil, odds: self, win: true)
    }

    var loose: Match {
        return Match(home: nil, away: nil, odds: self, win: false)
    }
}


// 对冲策略
func minHedgeOdds(originOdds: Float) -> Float {
    return 1 / (originOdds - 1) + 1
}

func hedge(originOdds: Float, originAmount: Int, hedgeOdds: Float) -> Array<String> {

    var resultArray = [String]()

    let _minHedgeOdds = minHedgeOdds(originOdds: originOdds)
    guard hedgeOdds > _minHedgeOdds else {
        let printString = "赔率未达到对冲要求，对冲赔率应大于\(_minHedgeOdds)"
        resultArray.append(printString)
        return resultArray
    }

    let min = Float(originAmount) / (hedgeOdds - 1.0)
    let max = (originOdds - 1.0) * Float(originAmount)
    let printString1 = "对冲额应保持在 [\(min)---\(max)]"
    resultArray.append(printString1)

    let mid = originOdds * Float(originAmount) / hedgeOdds
    let midNetwin = (hedgeOdds - 1.0) * mid - Float(originAmount)

    let printString2 = "对冲额\(mid), 确定获益:\(midNetwin)"
    let printString3 = "对冲额在[\(min)---\(mid)] 第一次投注中注获胜收益大"
    let printString4 = "对冲额在[\(mid)---\(max)] 第二次投注中注获胜收益大"

    resultArray.append(printString2)
    resultArray.append(printString3)
    resultArray.append(printString4)

    return resultArray
}


//MARK: 快速接口

/// 给进赔率以及命中与否，算收益
/// - Parameters:
///   - singleBet: 单场投注额
func calNetwin( _ matches: [Match], choose: Int, singleBet: Int) {
    let result = calNetwin(matches, choose: choose, singleBet: singleBet, nil)
    print("总投入：\(result.0), 盈利:\(result.1)")
}

func summary(_ matches: [Double], choose: Int, singleBet: Int) {
    matches.summary(choose: choose, singleBet: singleBet)
}

func summary(_ matches: [Match], choose: Int, singleBet: Int) {
    matches.summary(choose: choose, singleBet: singleBet)
}

protocol BetSummary {
    /// Array: [Match],[Double] Extension,
    /// 给进赔率，给出收益期望摘要,若是[Match]会忽略其命中与否属性
    func summary(choose: Int, singleBet: Int) -> String
}


//MARK: Calculate

//let matches = [3.5.win, 2.8.win, 1.09.win, 1.30.win, 1.80.loose, 1.43.win, 1.40.win]
//calNetwin(matches, choose: 5, singleBet: 100)
//summary(matches, choose: 5, singleBet: 100)
//
//let matches1 = [3.5, 2.8, 1.09, 1.30, 1.80, 1.43, 1.40]
//matches1.summary(choose: 5, singleBet: 100)

//let matches = [2.05.win, 2.11.win, 2.23.win, 1.11.win, 1.18.win, 1.18.win, 1.30.win, 1.92.win, 1.48.win, 1.24.win]
//

/*Progress
let matches = [2.05.win, 2.11.win, 2.23.win, 1.11.win, 1.30.win, 1.18.win, 1.92.win]
matches.summary(choose: 5, singleBet: 10)
//calNetwin(matches, choose: 5, singleBet: 10)
*/

// let matches = [2.05.win, 2.11.loose, 2.23.win, 1.11.win]
// matches.summary(choose: 3, singleBet: 200)
// calNetwin(matches, choose: 3, singleBet: 200)

//let matches = [1.17.win, 1.86.win, 1.55.win, 1.15.win, 1.22.win, 3.95.win, 1.42.win, 1.29.win, 1.47.win, 1.17.win]
// calNetwin(matches, choose: 8, singleBet: 5)

//let matches = [1.17.win, 1.86.win, 1.55.win, 1.17.win, 1.15.win, 1.47.win, 1.22.win]
//calNetwin(matches, choose: 5, singleBet: 100)

//let matches = [1.17.win, 1.86.win, 1.55.win, 1.15.win, 1.47.win, 1.66.win, 2.85.loose, 1.17.win, 1.27.win, 1.22.win]
//calNetwin(matches, choose: 8, singleBet: 10)
