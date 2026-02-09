import Fluent
import NIOAdvanced
import PgSQL
import Vapor
import ErrorHandle
import Policy
import PrivilegeModule

protocol SystemController: Controller where E == PrivilegeSystem.Errcase {}

enum ManyToManyAction {
    case attach
    case detach
}

extension SystemController {
    func __manyToMany<Left, Right, LM, RM, TM>(
        _ relations: [MTMRelation<Left, Right>],
        action: ManyToManyAction,
        label: String,
        errThrowing: E,
        siblingBuilder: @Sendable @escaping (Left) -> SiblingsProperty<LM, RM, TM>,
        modelsBuilder: @Sendable @escaping ([Right]) -> EventLoopRes<[RM], E>,
    ) -> EventLoopRes<Void, E>
        where LM: PGModel, RM: PGModel, E.ErrType == BscError<E>
    {
        db.trans { db in
            relations.flatMap { relation in
                relation.left.map { l in
                    modelsBuilder(relation.right).flatMap { rs in
                        let builder = siblingBuilder(l)
                        switch action {
                        case .attach:
                            return builder
                                .attach(rs, on: db)
                                .withError(errThrowing, "将\(label)关系插入中间表时失败", category: .internal)
                        case .detach:
                            return builder
                                .detach(rs, on: db)
                                .withError(errThrowing, "将\(label)关系中间表移除时失败", category: .internal)
                        }
                    }
                }
            }.flatten(on: db.eventLoop) // .flatten(on:) 会等待数组里所有的 Future 都变成成功状态，只要有一个失败，整体就会失败
        }
    }
}

func SortingSQL(uuids: [UUID]) -> String {
    let sqlArrayContent = uuids
        .map { "'\($0.uuidString)'" }
        .joined(separator: ", ")

    return "array_position(ARRAY[\(sqlArrayContent)]::uuid[], id)"
}
