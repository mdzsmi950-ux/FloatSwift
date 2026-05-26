import Foundation

struct FloatBackupPayload: Codable {
    var version = 1
    var budget: FloatBudget
    var debtPayoff: DebtPayoffLedger?
}
