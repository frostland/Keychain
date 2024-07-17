import Foundation
import Security
import XCTest

@testable import KeychainKit



final class KeychainTests : XCTestCase {
	
	override func setUp() async throws {
		try Keychain.GenericPassword.clearAll()
	}
	
	func testPerformSearch() throws {
		let baseQuery: [CFString: Any] = [
			kSecClass: kSecClassGenericPassword,
			kSecUseDataProtectionKeychain: kCFBooleanTrue!,
			kSecAttrService: "SecTest"
		]
		XCTAssertNoThrow(try secCall{
			var query = baseQuery
			query[kSecValueData] = Data([42])
			return SecItemAdd(query as CFDictionary, nil)
		})
		
		let ret = try XCTUnwrap(Keychain.performSearch({
			var query = baseQuery
			query[kSecReturnAttributes] = kCFBooleanTrue
			query[kSecReturnPersistentRef] = kCFBooleanTrue
			return query
		}()) as [CFString: Any]?)
		XCTAssertNotNil(ret[kSecValuePersistentRef])
	}
	
	func testBasicStorage() throws {
		let data = Data("hello!".utf8)
		let accessGroup = "DVL8GW97S8.fr.frostland.KeychainTestsHost"
		let keychainID = "fr.frostland.Keychain.testBasicStorage"
		let query = Keychain.GenericPassword(service: keychainID)
		let queryWithAccessGroup = Keychain.GenericPassword(service: keychainID, accessGroup: accessGroup)
		XCTAssertNil(try Keychain.GenericPassword.fetchOnlyMatchingFromKeychain(query: query, retrieveValue: true))
		XCTAssertNoThrow(try query.upsertInKeychain(updatedAttributes: .init(value: data)))
		XCTAssertEqual(try Keychain.GenericPassword.fetchOnlyMatchingFromKeychain(query: query, retrieveValue: true)?.value, data)
		XCTAssertEqual(try Keychain.GenericPassword.fetchOnlyMatchingFromKeychain(query: queryWithAccessGroup, retrieveValue: true)?.value, data)
		XCTAssertNoThrow(try query.deleteFromKeychain())
		XCTAssertNil(try Keychain.GenericPassword.fetchOnlyMatchingFromKeychain(query: query, retrieveValue: true))
	}
	
	func testClearKeychain() throws {
		let data = Data("hello!".utf8)
		let keychainID = "fr.frostland.Keychain.testClearKeychain"
		let query = Keychain.GenericPassword(service: keychainID)
		XCTAssertNoThrow(try query.upsertInKeychain(updatedAttributes: .init(value: data)))
		XCTAssertNoThrow(try Keychain.GenericPassword.clearAll())
		XCTAssertNil(try Keychain.GenericPassword.fetchOnlyMatchingFromKeychain(query: query, retrieveValue: true))
	}
	
	func testBasicStorageAccessGroup() throws {
		let data = Data("hello!".utf8)
		let accessGroup = "DVL8GW97S8.fr.frostland.KeychainTestsHost"
		let accessGroupShared = "DVL8GW97S8.fr.frostland.KeychainTestsHost.shared"
		let keychainID = "fr.frostland.Keychain.testBasicStorageAccessGroup"
		let query = Keychain.GenericPassword(service: keychainID)
		let queryWithAccessGroup = Keychain.GenericPassword(service: keychainID, accessGroup: accessGroup)
		let queryWithAccessGroupShared = Keychain.GenericPassword(service: keychainID, accessGroup: accessGroupShared)
		XCTAssertNil(try Keychain.GenericPassword.fetchOnlyMatchingFromKeychain(query: queryWithAccessGroup, retrieveValue: true))
		XCTAssertNil(try Keychain.GenericPassword.fetchOnlyMatchingFromKeychain(query: queryWithAccessGroupShared, retrieveValue: true))
		XCTAssertNoThrow(try queryWithAccessGroupShared.upsertInKeychain(updatedAttributes: .init(value: data)))
		XCTAssertEqual(try Keychain.GenericPassword.fetchOnlyMatchingFromKeychain(query: queryWithAccessGroupShared, retrieveValue: true)?.value, data)
		/* If the access group is not specified, all the access groups are searched.
		 * I think it is not possible to change this behavious (to search only the default one):
		 *  if this is needed, the default access group must be manually specified. */
		XCTAssertEqual(try Keychain.GenericPassword.fetchOnlyMatchingFromKeychain(query: query, retrieveValue: true)?.value, data)
		XCTAssertNil(try Keychain.GenericPassword.fetchOnlyMatchingFromKeychain(query: queryWithAccessGroup, retrieveValue: true))
		XCTAssertNoThrow(try queryWithAccessGroupShared.deleteFromKeychain())
		XCTAssertNil(try Keychain.GenericPassword.fetchOnlyMatchingFromKeychain(query: queryWithAccessGroupShared, retrieveValue: true))
	}
	
	func testClearKeychainAccessGroup() throws {
		let data = Data("hello!".utf8)
		let accessGroup = "DVL8GW97S8.fr.frostland.KeychainTestsHost.shared"
		let keychainID = "fr.frostland.Keychain.testClearKeychainAccessGroup"
		let query = Keychain.GenericPassword(service: keychainID, accessGroup: accessGroup)
		XCTAssertNoThrow(try query.upsertInKeychain(updatedAttributes: .init(value: data)))
		XCTAssertNoThrow(try Keychain.GenericPassword.clearAll(in: accessGroup))
		XCTAssertNil(try Keychain.GenericPassword.fetchOnlyMatchingFromKeychain(query: query, retrieveValue: true))
	}
	
	func testUpsertWithLease() throws {
		let data = Data("hello!".utf8)
		let accessGroup = "DVL8GW97S8.fr.frostland.KeychainTestsHost.shared"
		let keychainID = "fr.frostland.Keychain.testClearKeychainAccessGroup"
		let baseQuery = Keychain.GenericPassword(service: keychainID, accessGroup: accessGroup)
		XCTAssertNoThrow(try baseQuery.withGeneric(Data()).upsertInKeychainWithLease(updatedAttributes: .init(generic: Data([1]), value: data)))
		XCTAssertThrowsError(
			try baseQuery.withGeneric(Data()).upsertInKeychainWithLease(updatedAttributes: .init(generic: Data([2]), value: data)),
			"the upsert should fail as the local data is out-of-date",
			{ err in
				XCTAssertEqual(err as? KeychainError, .localItemOutOfDate)
			}
		)
		XCTAssertNoThrow(try baseQuery.withGeneric(Data([1])).upsertInKeychainWithLease(updatedAttributes: .init(generic: Data([2]), value: data)))
	}
	
}
